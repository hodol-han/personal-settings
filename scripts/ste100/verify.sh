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
# Known entries, compared by checksum so that this repository has no dictionary text. Each
# entry checks a case that a conversion error broke before. After an intended output change,
# print a checksum with:
#   jq -c --arg w WORD --arg p POS '[.[] | select(.word == $w and .pos == $p)]' \
#     dictionary.json | sha256sum | cut -c1-16
entry_sum() {
  jq -c --arg w "$1" --arg p "$2" '[.[] | select(.word == $w and .pos == $p)]' "$DICT" |
    sha256sum | cut -c1-16
}
while IFS='|' read -r sum pos word; do
  [[ "$(entry_sum "$word" "$pos")" == "$sum" ]] || fail "entry $word ($pos) changed"
done << 'ENTRIES'
678b84f43104f8e8|adj|NECESSARY
10318b6e3176150c|n|FUNCTION
4c5be1b8b6e18aa5||FOR EXAMPLE
f2427cb876b78634||such as
35e21584d5015f4c|adj|LONGITUDINAL
e6a2dcec3cfe94ba|adj|MATT (or MATTE)
7f75b758cb1d384c|adv|COUNTERCLOCKWISE
cdb5c5f957dc2fcd|v|carry
c5409be39d3b1b0f|v|mark
50a51519fbcc6199|adj|specific
be35708626582da3|v|function
16b0dff32fe88851|v|position
194e03f0eea227ec|adj|critical
1f12b08b5d94c06d|prep|ABOVE
949ae7dd75fa6983|v|carry out
b57f9ef8f75824b5|v|DRINK
4b56d3630e7c9b2f|adj|reverse
7770aef22605403b|conj|as
5b6d205ae4aff9d9|v|WILL
788161bd41827d9d|v|fix
a32ed45cf83ba4d6|adj|BAD
92bf9d189cd72541|v|have to
f75ff2362f1b1645|n|DATA
df7422e5f944b96e|v|GET
f045ee11b9a8bbe3|v|SWALLOW
ENTRIES
# The cases: no entry border in the PDF (LONGITUDINAL), lowercase words in brackets (MATT),
# a headword with no part of speech (FOR EXAMPLE), line-break hyphens (COUNTERCLOCKWISE, fix),
# alternatives after a note in an approved entry (ABOVE, DRINK), help notes on one or many
# lines, in the word cell, at the end of a sub-row, and in a sub-row of their own.
expect_absent() {
  jq -e --arg w "$1" 'all(.[]; (.word | ascii_downcase) != $w)' "$DICT" > /dev/null ||
    fail "$1 absent"
}
expect_absent practice
expect_absent meaning
jq_true '[.. | strings | select(test("[A-Za-z]- [A-Za-z]|\u00ad"))] | length == 0' \
  "no line-break hyphen with a space"

# Structure checks over all entries.
jq_true 'all(.[]; .approved == false or ([.senses[].ste_examples[]] | length > 0))' \
  "every approved entry has an STE example"
jq_true '[.[].senses[].ste_examples[] | select(test("\\b[a-z]{4,}\\b"))] | length <= 1' \
  "STE examples are in uppercase (no column mix)"
jq_true 'all(.[].senses[].non_ste_examples[]; test("[a-z]"))' \
  "non-STE examples are in normal case (no column mix)"
jq_true 'all(.[].senses[]; (.meaning // .alternative) | test("^\\(\\w+\\)$") | not)' \
  "no meaning or alternative is only a part of speech"
jq_true 'all(.[].senses[];
    (.meaning // .alternative) | test("use:|revised") | not)' \
  "no note or change-log text in senses"
jq_true 'all(.[].senses[]; all(.ste_examples[], .non_ste_examples[]; . != "Blank Page"))' \
  "no blank-page text in examples"
jq_true 'all(.[]; (.help | type) == "array") and all(.[].senses[]; (.help | type) == "array")' \
  "every entry and sense has a help list"
jq_true 'all(.[]; .forms | test("[a-z]{3,} [a-z]{3,}") | not)' "no note text in forms"
jq_true 'all(.[].senses[]; (.meaning // .alternative)
    | test("[a-z]{3,}.*[.:] [A-Z]{2,}|\\([a-z]+\\) [A-Z][a-z]+ .*[a-z]\\.$") | not)' \
  "no help sentence is joined to a meaning or alternative"
jq_true 'all(.[].senses[]; ((.meaning // .alternative) | test("^[a-z]") | not)
    and all(.help[]; test("^[a-z]") | not))' \
  "no text starts in the middle of a sentence"
echo "verified: dictionary.json"

# Rule text must be in the body of its Part 1 section page, not only in the change log.
# grep without -q reads all input, so awk does not fail on SIGPIPE under pipefail.
section() {
  awk -v head="## Page $1 " 'index($0, head) == 1 {f = 1; next} /^## /{f = 0} f' "$RULES"
}
section 1-1-1 | grep '^ *Rule 1\.1 ' > /dev/null || fail "Rule 1.1 on page 1-1-1"
section 1-9-1 | grep '^ *Rule 9\.1 ' > /dev/null || fail "Rule 9.1 on page 1-9-1"
# The rules refer to underlined text, and the sample tables keep their columns apart.
[[ "$(section 1-4-2 | grep -o '<u>' | wc -l)" -ge 5 ]] || fail "underlined text on page 1-4-2"
[[ "$(section 2-0-5 | grep -o '<u>' | wc -l)" -ge 2 ]] || fail "underlines on page 2-0-5"
[[ "$(section 2-0-19 | wc -l)" -gt 20 ]] || fail "missing page 2-0-19"
section 2-0-19 | grep '<u>' > /dev/null && fail "table borders read as underlines on 2-0-19"
section 2-0-5 | grep -E '^[A-Z]+ \([a-z]+\) {3,}[A-Z]' > /dev/null ||
  fail "table columns on page 2-0-5"
# Symbol font characters must be mapped to Unicode (for example the degree sign).
if grep -P '[\x{E000}-\x{F8FF}]' "$RULES" "$DICT" > /dev/null; then
  fail "private use characters in the output"
fi
echo "verified: ste100.md"

[[ "${1:-}" == --data-only ]] && exit 0

for path in .claude/CLAUDE.md .codex/AGENTS.md; do
  if ! grep -qF 'ste100/issue9/' "$HOME/$path"; then
    fail "no STE100 reference in ~/$path; install it with $REPO/scripts/agent-instructions/apply.sh"
  fi
  echo "verified: STE100 reference in ~/$path"
done
