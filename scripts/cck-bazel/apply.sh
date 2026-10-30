#!/usr/bin/env bash
# Restore the tracked personal Bazel snapshot, with backup and rollback on failure.
set -Eeuo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CACHE_DIR="$HOME/.cache/bazel/_bazel_$(id -un)/cache/disk"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/personal-settings/cck-bazel"
STAGE_DIR="$(mktemp -d)"
BACKUP_DIR="$STATE_DIR/backups/$(date -u +%Y%m%dT%H%M%SZ)-$$"
TIMER_ENABLED_BEFORE="$(systemctl --user is-enabled systemd-tmpfiles-clean.timer 2>/dev/null || true)"
TIMER_ACTIVE_BEFORE="$(systemctl --user is-active systemd-tmpfiles-clean.timer 2>/dev/null || true)"
PATHS=(
  .bazelrc
  .codex/AGENTS.md
  .claude/CLAUDE.md
  .config/user-tmpfiles.d/cck-bazel-cache.conf
)
declare -A EXISTED=()

cleanup() {
  rm -rf -- "$STAGE_DIR"
}
trap cleanup EXIT

mkdir -p "$STAGE_DIR/home"
while IFS= read -r line || [[ -n "$line" ]]; do
  printf '%s\n' "${line//@BAZEL_DISK_CACHE@/$CACHE_DIR}"
done < "$REPO/home/.bazelrc.template" > "$STAGE_DIR/home/.bazelrc"
install -D -m 0644 "$REPO/home/.codex/AGENTS.md" \
  "$STAGE_DIR/home/.codex/AGENTS.md"
install -D -m 0644 "$REPO/home/.claude/CLAUDE.md" \
  "$STAGE_DIR/home/.claude/CLAUDE.md"
install -D -m 0644 \
  "$REPO/home/.config/user-tmpfiles.d/cck-bazel-cache.conf" \
  "$STAGE_DIR/home/.config/user-tmpfiles.d/cck-bazel-cache.conf"

mkdir -p "$BACKUP_DIR/home"
for path in "${PATHS[@]}"; do
  if [[ -f "$HOME/$path" ]]; then
    EXISTED["$path"]=1
    install -D -m 0644 "$HOME/$path" "$BACKUP_DIR/home/$path"
  else
    EXISTED["$path"]=0
  fi
done

rollback() {
  local status="${1:-$?}"
  trap - ERR INT TERM
  set +e
  for path in "${PATHS[@]}"; do
    if [[ "${EXISTED[$path]}" == 1 ]]; then
      install -D -m 0644 "$BACKUP_DIR/home/$path" "$HOME/$path"
    else
      rm -f -- "$HOME/$path"
    fi
  done
  if [[ "$TIMER_ENABLED_BEFORE" != enabled ]]; then
    systemctl --user disable systemd-tmpfiles-clean.timer >/dev/null 2>&1
  fi
  if [[ "$TIMER_ACTIVE_BEFORE" != active ]]; then
    systemctl --user stop systemd-tmpfiles-clean.timer >/dev/null 2>&1
  fi
  echo "restore failed; previous files restored from $BACKUP_DIR" >&2
  exit "$status"
}
trap rollback ERR
trap 'rollback 130' INT
trap 'rollback 143' TERM

for path in "${PATHS[@]}"; do
  install -D -m 0644 "$STAGE_DIR/home/$path" "$HOME/$path"
done
systemd-tmpfiles --user --create \
  "$HOME/.config/user-tmpfiles.d/cck-bazel-cache.conf"
systemctl --user enable --now systemd-tmpfiles-clean.timer
"$REPO/scripts/cck-bazel/verify.sh"

trap - ERR INT TERM
echo "backup: $BACKUP_DIR"
