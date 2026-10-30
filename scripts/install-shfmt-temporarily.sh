#!/bin/bash

set -euo pipefail
set -o errexit

if command -v shfmt > /dev/null 2>&1; then
  echo "shfmt already installed."
  exit 0
fi

SHFMT_VERSION="3.11.0"
CURRENT_ARCH="$(dpkg-architecture --query DEB_HOST_ARCH)"
CURRENT_OS="$(dpkg-architecture --query DEB_HOST_ARCH_OS)"
BINARY_URL="https://github.com/mvdan/sh/releases/download/"
BINARY_URL+="v${SHFMT_VERSION}/"
BINARY_URL+="shfmt_v${SHFMT_VERSION}_${CURRENT_OS}_${CURRENT_ARCH}"

temp_directory=$(mktemp --directory)
# trap "rm -rf ${temp_directory}; echo Removed: ${temp_directory}" EXIT

curl -sSfL "${BINARY_URL}" --output "${temp_directory}/shfmt" &&
  chmod u+x "${temp_directory}/shfmt"

# Append for further execution.
export PATH="${PATH}:${temp_directory}"
cat << EOF
shfmt installed temporarily in '${temp_directory}'. Try:

    # To use until shutdown:
    alias shfmt='${temp_directory}/shfmt'

    # Or install it permanently(Not recommended); You may need to make an
    # alias or PATH export on your .bashrc if /usr/local/bin is not in PATH:
    mv '${temp_directory}/shfmt' /usr/local/bin/shfmt

EOF
