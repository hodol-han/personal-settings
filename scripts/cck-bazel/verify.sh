#!/usr/bin/env bash
# Verify installed files, effective Bazel rc, cache access, and cleanup policy.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CCK_WORKSPACE="${CCK_WORKSPACE:-$HOME/git/cck}"
CACHE_DIR="$HOME/.cache/bazel/_bazel_$(id -un)/cache/disk"
EXPECTED_RC="$(mktemp)"
trap 'rm -f -- "$EXPECTED_RC"' EXIT

while IFS= read -r line || [[ -n "$line" ]]; do
  printf '%s\n' "${line//@BAZEL_DISK_CACHE@/$CACHE_DIR}"
done < "$REPO/home/.bazelrc.template" > "$EXPECTED_RC"
cmp "$EXPECTED_RC" "$HOME/.bazelrc"
echo "verified: ~/.bazelrc"

cmp "$REPO/home/.config/user-tmpfiles.d/cck-bazel-cache.conf" \
  "$HOME/.config/user-tmpfiles.d/cck-bazel-cache.conf"
echo "verified: ~/.config/user-tmpfiles.d/cck-bazel-cache.conf"

systemd-tmpfiles --user --create \
  "$HOME/.config/user-tmpfiles.d/cck-bazel-cache.conf"
systemctl --user is-enabled systemd-tmpfiles-clean.timer
systemctl --user is-active systemd-tmpfiles-clean.timer
probe="$(mktemp "$CACHE_DIR/.verify.XXXXXX")"
rm -f -- "$probe"
echo "verified: writable shared Bazel disk cache"

test -f "$CCK_WORKSPACE/.bazeliskrc"
rc_output="$(cd "$CCK_WORKSPACE" && bazel --batch info --announce_rc release 2>&1)"
grep -F -- "Reading rc options for 'info' from $HOME/.bazelrc:" \
  <<< "$rc_output" > /dev/null
grep -F -- "--disk_cache=$CACHE_DIR" <<< "$rc_output" > /dev/null
echo "verified: CCK effective Bazel rc"
