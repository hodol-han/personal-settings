#!/usr/bin/env bash
# Verify the local ASD-STE100 copy and the agent instruction references to it.
# Usage: verify.sh [--data-only]   (--data-only skips the instruction file check)
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
MD5=9c720341c350ed77943b2c73d01c716f
DATA_DIR="${STE100_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/ste100/issue9}"
VENV="${XDG_CACHE_HOME:-$HOME/.cache}/personal-settings/ste100-venv"
PDF="$DATA_DIR/ASD-STE100_ISSUE9.pdf"
DICT="$DATA_DIR/dictionary.json"
RULES="$DATA_DIR/ste100.md"

fail() {
  echo "verify failed: $*" >&2
  exit 1
}

[[ -f "$PDF" ]] || fail "missing $PDF"
[[ "$(md5sum "$PDF" | cut -d' ' -f1)" == "$MD5" ]] || fail "PDF checksum mismatch"
echo "verified: PDF checksum"

# Each PDF page is in one output: a ste100.md heading or the page of a dictionary entry.
count_pages='import pdfplumber, sys; print(len(pdfplumber.open(sys.argv[1]).pages))'
pages="$("$VENV/bin/python" -c "$count_pages" "$PDF")"
covered="$(
  {
    sed -n 's/^## .*PDF page \([0-9]*\))\{0,1\}$/\1/p' "$RULES"
    jq -r '.[].pdf_page' "$DICT"
  } | sort -nu | wc -l
)"
[[ "$covered" == "$pages" ]] || fail "outputs cover $covered of $pages PDF pages"
echo "verified: all $pages PDF pages"

jq_true() {
  jq -e "$1" "$DICT" > /dev/null || fail "dictionary check: $2"
}
# Known dictionary facts: word, part of speech, approved status, and alternatives.
expect_alt() {
  jq -e --arg w "$1" --arg p "$2" --arg a "$3" \
    'any(.[]; .word == $w and .pos == $p and .approved == false
      and any(.senses[]; .alternative == $a))' "$DICT" > /dev/null || fail "$1 ($2) -> $3"
}
expect_approved() {
  jq -e --arg w "$1" --arg p "$2" \
    'any(.[]; .word == $w and .pos == $p and .approved == true)' "$DICT" > /dev/null ||
    fail "$1 ($2) approved"
}
expect_absent() {
  jq -e --arg w "$1" 'all(.[]; (.word | ascii_downcase) != $w)' "$DICT" > /dev/null ||
    fail "$1 absent"
}
expect_approved NECESSARY adj
expect_approved FUNCTION n
expect_approved "FOR EXAMPLE" ""
expect_alt carry v "TRANSMIT (v)"
expect_alt mark v "IDENTIFY (v)"
expect_alt specific adj "APPROVED (adj)"
expect_alt function v "OPERATE (v)"
expect_alt position v "PUT (v)"
expect_alt critical adj "VERY IMPORTANT"
expect_alt "such as" "" "FOR EXAMPLE"
expect_absent practice
expect_absent meaning
jq_true 'any(.[]; .word == "ABOVE" and any(.senses[]; .alternative == "MORE THAN"))' \
  "alternatives after a note in an approved entry"

# Structure checks over all entries.
jq_true 'all(.[]; .approved == false or ([.senses[].ste_examples[]] | length > 0))' \
  "every approved entry has an STE example"
jq_true '[.[].senses[].ste_examples[] | select(test("\\b[a-z]{4,}\\b"))] | length <= 5' \
  "STE examples are in uppercase (no column mix)"
jq_true 'all(.[].senses[].non_ste_examples[]; test("[a-z]"))' \
  "non-STE examples are in normal case (no column mix)"
jq_true 'all(.[].senses[]; (.meaning // .alternative) | test("^\\(\\w+\\)$") | not)' \
  "no meaning or alternative is only a part of speech"
jq_true 'all(.[].senses[];
    (.meaning // .alternative) | test("For other meanings|example revised") | not)' \
  "no note or change-log text in senses"
jq_true 'all(.[].senses[]; all(.ste_examples[], .non_ste_examples[]; . != "Blank Page"))' \
  "no blank-page text in examples"
echo "verified: dictionary.json"

# Rule text must be in the body of its Part 1 section page, not only in the change log.
# grep without -q reads all input, so awk does not fail on SIGPIPE under pipefail.
section() {
  awk -v head="## Page $1 " 'index($0, head) == 1 {f = 1; next} /^## /{f = 0} f' "$RULES"
}
section 1-1-1 | grep '^Rule 1\.1 ' > /dev/null || fail "Rule 1.1 on page 1-1-1"
section 1-9-1 | grep '^Rule 9\.1 ' > /dev/null || fail "Rule 9.1 on page 1-9-1"
echo "verified: ste100.md"

[[ "${1:-}" == --data-only ]] && exit 0

for path in .claude/CLAUDE.md .codex/AGENTS.md; do
  if ! grep -qF 'ste100/issue9/' "$HOME/$path"; then
    fail "no STE100 reference in ~/$path; install it with $REPO/scripts/cck-bazel/apply.sh"
  fi
  echo "verified: STE100 reference in ~/$path"
done
