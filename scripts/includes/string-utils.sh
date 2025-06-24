#!/bin/bash

# Common string utilities for shell scripts
# This script can be sourced by other scripts to provide string manipulation functions

# Function to escape special regex characters in strings
# Returns: the input string with regex special characters escaped (e.g., ".?*" becomes "\.\?\*")
# Usage: escaped=$(escape_regex "a.b*c")

escape_regex() {
  # shellcheck disable=SC2016
  # SC2016 is a false positive here, as we intentionally prevent expansion.
  local pattern='s/[]\[\.^$(){}*+?|]/\\&/g'
  printf '%s' "$1" | sed "$pattern"
}

# Function to escape spaces and special characters for shell commands
escape_shell() {
  printf '%q' "$1"
}

# Function to trim whitespace from string
trim() {
  local var="$*"

  # Remove leading whitespace
  var="${var#"${var%%[![:space:]]*}"}"

  # Remove trailing whitespace
  var="${var%"${var##*[![:space:]]}"}"

  printf '%s' "$var"
}
