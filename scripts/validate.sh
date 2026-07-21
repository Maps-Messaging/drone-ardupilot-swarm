#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

required_files=(
  VERSION
  Makefile
  README.md
  docs/mavlink-router.md
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
  packaging/build-deb.sh
  packaging/upload-deb.sh
  packaging/debian/postinst
  packaging/debian/copyright
  packaging/debian/README.Debian
  packaging/wrappers/ardupilot-swarm-install
  packaging/wrappers/ardupilot-swarm-update
  packaging/wrappers/ardupilot-swarm-uninstall
  .buildkite/pipeline.yml
)

for file in "${required_files[@]}"; do
  if [[ ! -f "${file}" ]]; then
    echo "Missing required file: ${file}" >&2
    exit 1
  fi
done

while IFS= read -r -d '' script; do
  bash -n "${script}"
done < <(
  find . \
    -path './build' -prune -o \
    -path './dist' -prune -o \
    -type f \
    \( -name '*.sh' -o -path './scripts/*' -o -path './packaging/wrappers/*' -o -name 'install.sh' -o -name 'update.sh' -o -name 'uninstall.sh' \) \
    -print0
)

if find . -path './dist' -prune -o -path './build' -prune -o -type f -name '*.parm' -print | grep -q .; then
  echo "A proprietary .parm file must not be included in this project." >&2
  exit 1
fi

if grep -RniE --exclude=validate.sh --exclude-dir=.git --exclude-dir=build --exclude-dir=dist 'stickleback' .; then
  echo "Project contains deployment-specific naming." >&2
  exit 1
fi

if grep -RniE \
  --exclude=validate.sh \
  'MapsMessaging|/opt/maps|maps-' \
  install.sh update.sh uninstall.sh config scripts systemd; then
  echo "Runtime installation contains organisation-specific naming." >&2
  exit 1
fi

if grep -qE '(^|, )[[:space:]]*mavlink-router([ ,]|$)' packaging/build-deb.sh; then
  echo "Debian package must not depend on an unavailable mavlink-router package." >&2
  exit 1
fi

if ! grep -q 'chmod +x packaging/\*.sh scripts/\*.sh \*.sh' .buildkite/pipeline.yml; then
  echo "Buildkite validation/build steps must restore executable script permissions." >&2
  exit 1
fi

if ! grep -q 'chmod +x packaging/upload-deb.sh' .buildkite/pipeline.yml; then
  echo "Buildkite publish step must restore upload script permissions." >&2
  exit 1
fi

if command -v shellcheck >/dev/null 2>&1; then
  mapfile -d '' shell_scripts < <(
    find . \
      -path './build' -prune -o \
      -path './dist' -prune -o \
      -type f \
      \( -name '*.sh' -o -path './scripts/*' -o -path './packaging/wrappers/*' -o -name 'install.sh' -o -name 'update.sh' -o -name 'uninstall.sh' \) \
      -print0
  )
  shellcheck "${shell_scripts[@]}"
fi

echo "Validation passed."
