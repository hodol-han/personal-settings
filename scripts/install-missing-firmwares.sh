#!/bin/bash

FIRMWARE_DIR="/lib/firmware"
LINUX_FIRMWARE_URL="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git"
LINUX_FIRMWARE_GIT_TAG="${LINUX_FIRMWARE_VERSION:-}"

MISSING_FIRMWARE_FILES=(
  "intel/ibt-0190-0291-pci.ddc"
  "intel/ibt-0190-0291-pci.sfi"
)

usage() {
  echo "Usage: $(basename "$0")"
  echo "This script installs missing firmware files."
  echo "The following firmware files will be installed:"
  for firmware_file in "${MISSING_FIRMWARE_FILES[@]}"; do
    echo "  $firmware_file"
  done

  exit 0
}

url_from_filepath() {
  local firmware_file="$1"
  echo -n "${LINUX_FIRMWARE_URL}/plain/${firmware_file}"
  test -n "$LINUX_FIRMWARE_GIT_TAG" &&
    echo -n "?h=${LINUX_FIRMWARE_GIT_TAG}"
}

# Function to download and install missing firmware files
install_firmware() {
  local firmware_file="$1"
  local url

  # Check if the file already exists
  if [ -f "$FIRMWARE_DIR/$firmware_file" ]; then
    echo "Firmware file $firmware_file already exists."
    return
  fi

  url="$(url_from_filepath "$firmware_file")"

  # Create the directory if it doesn't exist
  install -d -m755 "$FIRMWARE_DIR/$(dirname "$firmware_file")"

  # Download the firmware file.
  # Note we just install them without dpkg-divert or similar tools. This is to allow
  # the linux-firmware package to overwrite these files during updates, ensuring
  # that the system always has the latest firmware versions provided by the package.
  if curl -o "$FIRMWARE_DIR/$firmware_file" "$url"; then
    echo "Successfully downloaded $firmware_file to $FIRMWARE_DIR."
  else
    echo "Failed to download $firmware_file from $url."
    return 1
  fi
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
  usage
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/ensure-root.sh
source "${script_dir}/ensure-root.sh"

ensure_root "$@"

# Check if curl is installed
if ! command -v curl > /dev/null 2>&1; then
  echo "curl is not installed. Please install it and try again."
  exit 1
fi

# Check if the firmware directory exists
if [ ! -d "$FIRMWARE_DIR" ]; then
  echo "Firmware directory $FIRMWARE_DIR does not exist."
  exit 1
fi

# Check if the firmware files are missing and install them
for firmware_file in "${MISSING_FIRMWARE_FILES[@]}"; do
  install_firmware "$firmware_file" || {
    echo "Failed to install $firmware_file."
    exit 1
  }
done
