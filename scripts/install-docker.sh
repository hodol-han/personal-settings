#!/bin/bash

set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/ensure-root.sh
source "${script_dir}/ensure-root.sh"

ensure_root "$@"

## See https://docs.docker.com/engine/install/debian/

conflicting_packages=(
  docker.io
  docker-doc
  docker-compose
  podman-docker
  containerd
  runc
)

docker_packages=(
  docker-ce
  docker-ce-cli
  containerd.io
  docker-buildx-plugin
  docker-compose-plugin
)

# shellcheck disable=SC2016
apt-get remove --yes "$(
  dpkg-list \
    --showformat '${db:Status-Abbrev}\t${Binary:Package}\n' \
    --show "${conflicting_packages[@]}" |
    grep '^ii' |
    awk '{ print $2 }'
)"
apt-get install --yes "${docker_packages[@]}"
