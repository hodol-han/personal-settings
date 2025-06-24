#!/bin/bash
#
# Description: A reusable script to ensure that the main script is run as root.
#              This version is "bulletproofed" with Bash existence and version checks.
#
# Usage in your main script:
#   # Include and call this when you need.
#   ensure_root "$@"
#

ensure_root() {
  # --- Pre-flight Checks (Guard Clauses) ---

  # 1. Check if this is a Bash shell. BASH_SOURCE and BASH_VERSION are Bash-specific.
  if [ -z "${BASH_VERSION-}" ]; then
    echo "Error: This utility must be sourced from a Bash shell." >&2
    return 1
  fi

  # 2. Check for the minimum required Bash version.
  # Negative array indexing (${BASH_SOURCE[-1]}) was introduced in Bash 4.3.
  local MIN_BASH_VER="4.3"
  if [[ "${BASH_VERSION}" < "${MIN_BASH_VER}" ]]; then
    echo "Error: Bash version ${MIN_BASH_VER} or newer is required to use this utility." >&2
    echo "Your current version is ${BASH_VERSION}." >&2
    return 1
  fi

  # 3. If already root, do nothing and exit successfully.
  if [ "$(id -u)" = '0' ]; then
    return 0
  fi

  # --- Main Logic ---
  # This part is only reached if the script is NOT run as root and meets all requirements.

  # Get the path of the top-level script from the call stack.
  local top_level_script="${BASH_SOURCE[-1]}"

  # Inform the user.
  echo "$(basename "$top_level_script") must be run as root. Re-running with sudo..." >&2

  # Re-execute the top-level script with sudo.
  exec sudo -E -- "$top_level_script" ${@+"$@"}
}
