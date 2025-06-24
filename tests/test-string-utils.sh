#!/bin/bash

# Unit tests for string-utils.sh

# Get the directory where this script is located
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/../scripts/string-utils.sh"

echo "Running unit tests for string-utils.sh..."

# Test escape_regex
test_escape_regex() {
  local input="a.b*c"
  local expected="a\.b\*c"
  local result
  result=$(escape_regex "$input")
  if [[ "$result" == "$expected" ]]; then
    echo "escape_regex: PASS"
  else
    echo "escape_regex: FAIL (expected '$expected', got '$result')"
    exit 1
  fi
}

# Test escape_shell
test_escape_shell() {
  local input='a b"c'
  local expected=$'a\\ b\\\"c'
  local result
  result=$(escape_shell "$input")
  # shellcheck disable=SC2059
  if [[ "$result" == "$expected" ]]; then
    echo "escape_shell: PASS"
  else
    echo "escape_shell: FAIL (expected '$expected', got '$result')"
    exit 1
  fi
}

# Test trim
test_trim() {
  local input="   hello world   "
  local expected="hello world"
  local result
  result=$(trim "$input")
  if [[ "$result" == "$expected" ]]; then
    echo "trim: PASS"
  else
    echo "trim: FAIL (expected '$expected', got '$result')"
    exit 1
  fi
}

test_escape_regex
test_escape_shell
test_trim

echo "All tests passed."
