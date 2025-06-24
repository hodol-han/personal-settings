#!/bin/bash

# Usage:
#   1. Include and call
#       source detect-display-server.sh
#       display_server=$(detect_display_server)
#   2. Execute directly
#       ./detect-display-server.sh

# Common utility to detect the current display server (Wayland or X11)
# This script can be sourced by other scripts to provide display server detection

detect_display_server() {
  if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] || [[ "${WAYLAND_DISPLAY:-}" ]]; then
    echo "wayland"
  elif [[ "${DISPLAY:-}" ]]; then
    echo "x11"
  else
    # Fallback: check if Wayland compositor is running
    if pgrep -x "gnome-shell|kwin_wayland|sway|weston" > /dev/null 2>&1; then
      echo "wayland"
    else
      echo "x11"
    fi
  fi
}

# If script is executed directly (not sourced), output the detected display server
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  detect_display_server
fi
