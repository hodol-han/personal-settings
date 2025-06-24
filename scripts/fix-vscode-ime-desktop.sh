#!/bin/bash

# This script automatically detects if running on Wayland or X11 and configures
# VS Code desktop files accordingly:
# - On Wayland: adds IME options, removes X11 options
# - On X11: adds X11 options, removes Wayland options
# A backup (.bak) of each file is created before modification.

set -euo pipefail

# --- Constants and Global Variables ---

# Get the directory where this script is located
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define platform-specific options
readonly X11_OPTIONS=(
  "--ozone-platform=x11"
)
readonly WAYLAND_OPTIONS=(
  "--enable-wayland-ime"
  "--wayland-text-input-version=3"
)
readonly FILES=(
  "/usr/share/applications/code.desktop"
  "/usr/share/applications/code-url-handler.desktop"
)

# These will be populated by configure_options
add_options=()
remove_options=()
temp_files_to_clean=()

# Source utility scripts
# shellcheck source=scripts/string-utils.sh
source "${script_dir}/string-utils.sh"

# --- Functions ---

ensure_root() {
  if [ "$(id -u)" != '0' ]; then
    echo "$(basename "$0") requires to be run as root. Entering root..."
    # Pass the DISPLAY_SERVER variable to the new process if it was set.
    exec sudo -- \
      env DISPLAY_SERVER="${DISPLAY_SERVER:-}" "${BASH_SOURCE[0]}" "$@"
  fi
}

configure_options() {
  local display_server="$1"
  if [[ "${display_server,,}" == "wayland" ]]; then
    add_options=("${WAYLAND_OPTIONS[@]}")
    remove_options=("${X11_OPTIONS[@]}")
  elif [[ "${display_server,,}" == "x11" ]]; then
    add_options=("${X11_OPTIONS[@]}")
    remove_options=("${WAYLAND_OPTIONS[@]}")
  else
    echo "Error: Unsupported display server: $display_server" >&2
    exit 1
  fi
}

add_options_to_file() {
  local file="$1"
  shift
  local options_to_add=("$@")

  for option in "${options_to_add[@]}"; do
    local escaped_option
    escaped_option=$(escape_regex "$option")

    # This checks if the option is surrounded by spaces, or at the start/end of the arguments.
    # We check inside the Exec line specifically.
    if ! grep -q -E "^\s*Exec=.*([[:space:]]|^)${escaped_option}([[:space:]]|$)" "$file"; then
      sed -i -E "s/^(Exec=.*\bcode\b)(.*)$/\1 ${option}\2/" "$file"
    fi
  done
}

remove_options_from_file() {
  local file="$1"
  shift
  local options_to_remove=("$@")

  for option in "${options_to_remove[@]}"; do
    local escaped_option
    escaped_option=$(escape_regex "$option")

    # We match one or more spaces BEFORE the option, and then the option itself.
    # This reliably removes the option and its preceding space.
    sed -i -E "s/[[:space:]]+${escaped_option}//g" "$file"
  done
}

update_file_atomically() {
  local original_file="$1"
  local modified_file="$2"

  if ! diff -q "$original_file" "$modified_file" > /dev/null; then
    echo "Updating $original_file..."

    # Backup and replace the original file atomically
    local timestamp
    timestamp=$(date +%Y%m%d%H%M%S)

    mv "$original_file" "$original_file.bak.$timestamp"
    mv "$modified_file" "$original_file"

    echo "$original_file updated."
  else
    rm "$modified_file" # remove temp file if no changes
    echo "$original_file is already up to date."
  fi
}

process_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "File $file not found."
    return
  fi

  echo "Processing $file ..."

  # Create a temporary file to apply changes to, preserving attributes
  local temp_modified_file
  temp_modified_file=$(mktemp)
  temp_files_to_clean+=("$temp_modified_file")

  cp -a "$file" "$temp_modified_file"

  remove_options_from_file "$temp_modified_file" "${remove_options[@]}"
  add_options_to_file "$temp_modified_file" "${add_options[@]}"

  update_file_atomically "$file" "$temp_modified_file"
}

main() {
  ensure_root "$@"

  # Set a trap to clean up all temporary files on exit.
  # Using an array to handle multiple temp files if the script is extended.
  trap 'rm -f "${temp_files_to_clean[@]}"' EXIT HUP INT QUIT PIPE TERM

  # Auto-detected, so specify only when necessary.
  local display_server="${DISPLAY_SERVER:-}"

  # Detect display server
  if [[ -z "${display_server}" ]]; then
    display_server=$("${script_dir}/detect-display-server.sh")
    echo "Detected display server: $display_server"
  else
    echo "Using predefined display server: $display_server"
  fi

  configure_options "$display_server"

  for file in "${FILES[@]}"; do
    process_file "$file"
  done

  echo "Update complete."
}

# --- Main Execution ---
main "$@"
