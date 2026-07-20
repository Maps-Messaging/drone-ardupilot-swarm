#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

required_files=(
  VERSION
  Makefile
  README.md
  install.sh
  update.sh
  uninstall.sh
  config/ardupilot-swarm.conf.example
  config/mavlink-router-main.conf
  config/mavlink-router-ardupilot.conf.in
  scripts/start-ardupilot-swarm
  scripts/stop-ardupilot-swarm
  scripts/ardupilot-swarm-configure-gcs
  scripts/ardupilot-swarm-install-parameters
  systemd/ardupilot-swarm.service.in
)

for file in "${required_files[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "Missing required file: ${file}" >&2
    exit 1
  fi
done

while IFS= read -r -d '' script; do
  bash -n "${script}"
done < <(find . -type f \( -name '*.sh' -o -path './scripts/*' -o -name 'install.sh' -o -name 'update.sh' -o -name 'uninstall.sh' \) -print0)

if find . -path './dist' -prune -o -type f -name '*.parm' -print | grep -q .; then
  echo "A proprietary .parm file must not be included in this project." >&2
  exit 1
fi

if grep -RniE --exclude=validate.sh --exclude-dir=.git --exclude-dir=dist 'MapsMessaging|/opt/maps|maps-' .; then
  echo "Project contains organisation-specific naming." >&2
  exit 1
fi

if command -v shellcheck >/dev/null 2>&1; then
  mapfile -d '' shell_scripts < <(find . -type f \( -name '*.sh' -o -path './scripts/*' -o -name 'install.sh' -o -name 'update.sh' -o -name 'uninstall.sh' \) -print0)
  shellcheck "${shell_scripts[@]}"
fi

echo "Validation passed."
