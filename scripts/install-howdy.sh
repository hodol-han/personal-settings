#!/bin/bash

# This script installs Howdy, a facial recognition tool for Linux.
# Source: https://ubuntuhandbook.org/index.php/2024/10/howdy-ubuntu-2404/

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/includes/ensure-root.sh
source "${script_dir}/includes/ensure-root.sh"

ensure_root "$@"

# Original howdy package by boltgolt breaks system packages as it uses pip to
# install required packages, so use the PPA from ubuntuhandbook1 instead. It
# provides a patched version of Howdy to avoid this. Never enable
# 'global.break-system-packages' option for pip unless you can bear.
# See: https://github.com/boltgolt/howdy/blob/v2.6.1/debian/postinst
add-apt-repository ppa:ubuntuhandbook1/howdy

# Avoid --yes to prevent unintended system collapse by removing essential packages.
apt update && apt install howdy
