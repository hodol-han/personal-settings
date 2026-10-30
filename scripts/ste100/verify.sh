#!/usr/bin/env bash
# Verify the local ASD-STE100 copy and the agent instruction references to it.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
MD5=9c720341c350ed77943b2c73d01c716f
DATA_DIR="${STE100_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/ste100/issue9}"
DICT="$DATA_DIR/dictionary.json"
RULES="$DATA_DIR/ste100.md"

[[ "$(md5sum "$DATA_DIR/ASD-STE100_ISSUE9.pdf" | cut -d' ' -f1)" == "$MD5" ]]
echo "verified: PDF checksum"

# Known dictionary facts: word, part of speech, approved status, and alternative.
expect_alt() {
  jq -e --arg w "$1" --arg p "$2" --arg a "$3" \
    'any(.[]; .word == $w and .pos == $p and .approved == false
      and any(.senses[]; .alternative == $a))' "$DICT" >/dev/null
}
expect_approved() {
  jq -e --arg w "$1" --arg p "$2" \
    'any(.[]; .word == $w and .pos == $p and .approved == true)' "$DICT" >/dev/null
}
expect_absent() {
  jq -e --arg w "$1" 'all(.[]; (.word | ascii_downcase) != $w)' "$DICT" >/dev/null
}
expect_approved NECESSARY adj
expect_approved FUNCTION n
expect_alt carry v "TRANSMIT (v)"
expect_alt mark v "IDENTIFY (v)"
expect_alt specific adj "APPROVED (adj)"
expect_alt function v "OPERATE (v)"
expect_absent practice
expect_absent meaning
# Change-log lines ("... STE example revised.") must not become entries.
jq -e 'all(.[].senses[]; ((.meaning // .alternative) | test("example revised") | not))' \
  "$DICT" >/dev/null
echo "verified: dictionary.json"

# Rule text must be in the body of its Part 1 section page, not only in the change log.
# grep without -q reads all input, so awk does not fail on SIGPIPE under pipefail.
section() {
  awk -v head="## Page $1 " 'index($0, head) == 1 {f = 1; next} /^## /{f = 0} f' "$RULES"
}
section 1-1-1 | grep '^Rule 1\.1 ' >/dev/null
section 1-9-1 | grep '^Rule 9\.1 ' >/dev/null
echo "verified: ste100.md"

for path in .claude/CLAUDE.md .codex/AGENTS.md; do
  # The instruction files name the directory with a literal tilde.
  # shellcheck disable=SC2088
  if ! grep -qF '~/.local/share/ste100/issue9/' "$HOME/$path"; then
    echo "missing STE100 reference in ~/$path; install it with" \
      "$REPO/scripts/cck-bazel/apply.sh" >&2
    exit 1
  fi
  echo "verified: STE100 reference in ~/$path"
done
