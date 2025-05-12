#!/bin/bash

set -euo pipefail
set -o errexit

WINE_BRANCH="stable"
DISTRO=$(lsb_release -c | awk '{print $2}')
WINE_PACKAGE="winehq-${WINE_BRANCH}"

if command -v wine > /dev/null 2>&1; then
  echo "wine already installed."
  exit 0
fi

# Execute the script as root if not already running as root.
# This is necessary for installing packages.
if [ "$(id -u)" != '0' ]; then
  echo "$(basename "$0") requires to be run as root. Entering root..."
  exec sudo -- "${BASH_SOURCE[0]}" "$@"
fi

# See https://gitlab.winehq.org/wine/wine/-/wikis/Debian-Ubuntu
# for the latest version.
install -d -m755 /etc/apt/keyrings
wget -O - https://dl.winehq.org/wine-builds/winehq.key |
  gpg --dearmor --yes -o /etc/apt/keyrings/winehq-archive.key -

wget -NP /etc/apt/sources.list.d \
  "https://dl.winehq.org/wine-builds/ubuntu/dists/${DISTRO}/winehq-${DISTRO}.sources"

# CAUTION: Check packages being removed during installation. This may break
# your system unintentionally.
apt-get update &&
  apt-get install --install-recommends --yes "$WINE_PACKAGE"
