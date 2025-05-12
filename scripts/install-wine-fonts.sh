#!/bin/bash

set -euo pipefail
set -o errexit

WINEPREFIX="${HOME}/.wine"

if ! command -v wine > /dev/null 2>&1; then
  echo "Please install wine before running this script."
  exit 1
fi

test -d "${WINEPREFIX:-}" || {
  echo >&2 "'$WINEPREFIX' is either not set or not a valid directory."
  exit 1
}

# Install fonts for Korean. See https://wikidocs.net/273781 for more details.
wget -N \
  -O "$WINEPREFIX/drive_c/windows/Fonts/gulim.ttc" \
  https://github.com/googlefonts/gulim/raw/refs/heads/main/fonts/ttc/gulim-Regular.ttc

# Note 'fonts-nanum' is optional.
dpkg -s fonts-nanum &> /dev/null || {
  echo "fonts-nanum is not installed. Installing..."
  sudo apt-get install fonts-nanum
}
