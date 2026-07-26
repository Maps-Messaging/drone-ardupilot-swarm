#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

PATCH_FILE="patches/ardupilot/0001-allow-guided-throttle-before-takeoff.patch"

required_files=(
  VERSION
  Makefile
  README.md
  CHANGELOG.md
  ardupilot-swarm-setup-and-usage.md
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
  "${PATCH_FILE}"
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

bash -n config/ardupilot-swarm.conf.example

if find . -path './dist' -prune -o -path './build' -prune -o -type f -name '*.parm' -print | grep -q .; then
  echo "A proprietary .parm file must not be included in this project." >&2
  exit 1
fi

if grep -RniE \
  --exclude=validate.sh \
  'MapsMessaging|/opt/maps' \
  install.sh update.sh uninstall.sh config scripts systemd; then
  echo "Runtime installation contains organisation-specific naming." >&2
  exit 1
fi

if grep -qE '(^|, )[[:space:]]*mavlink-router([ ,]|$)' packaging/build-deb.sh; then
  echo "Debian package must not depend on an unavailable mavlink-router package." >&2
  exit 1
fi

if ! grep -q 'python3-pip' install.sh; then
  echo "Installer must install python3-pip before Python build dependencies." >&2
  exit 1
fi

if ! grep -q "'empy==3.3.4'" install.sh; then
  echo "Installer must install the ArduPilot-required empy==3.3.4 package." >&2
  exit 1
fi

if ! grep -q 'pkgs.tailscale.com/stable' install.sh || ! grep -q 'apt-get install -y tailscale' install.sh; then
  echo "Installer must configure the official Tailscale repository and install the tailscale package." >&2
  exit 1
fi

if ! grep -q 'MAPS_PACKAGES=("maps" "maps-apps" "maps-drone")' install.sh; then
  echo "Installer must define the Maps server, apps, and drone packages." >&2
  exit 1
fi

if ! grep -q 'apt-get install -y "${MAPS_PACKAGES\[@\]}"' install.sh; then
  echo "Installer must install Maps packages through APT without a versioned package URL." >&2
  exit 1
fi

if grep -Eq 'maps-drone_[0-9]|maps-drone.*/pool/' install.sh README.md ardupilot-swarm-setup-and-usage.md; then
  echo "Maps packages must not be pinned to a versioned .deb path." >&2
  exit 1
fi

if ! grep -q 'systemctl enable --now tailscaled.service' install.sh; then
  echo "Installer must enable and start tailscaled.service." >&2
  exit 1
fi

if grep -Eq '^[[:space:]]*(sudo[[:space:]]+)?tailscale[[:space:]]+up([[:space:]]|$)' install.sh; then
  echo "Installer must leave Tailscale authentication for manual post-install configuration." >&2
  exit 1
fi

if ! grep -q 'control_mode == &mode_guided' "${PATCH_FILE}"; then
  echo "Managed ArduPilot patch must disable throttle suppression in GUIDED mode." >&2
  exit 1
fi

if ! grep -q 'git -C "${ARDUPILOT_DIR}" apply --check' install.sh; then
  echo "Installer must verify the managed ArduPilot patch before applying it." >&2
  exit 1
fi

if ! grep -q 'cp -a "${ROOT_DIR}/patches"' packaging/build-deb.sh; then
  echo "Debian package must include the managed ArduPilot patch directory." >&2
  exit 1
fi

if grep -q -- '--model' scripts/start-ardupilot-swarm; then
  echo "The virtual vehicles must remain normal fixed-wing ArduPlane models." >&2
  exit 1
fi

# shellcheck source=/dev/null
source config/ardupilot-swarm.conf.example
vehicle_count="${#SYSTEM_IDS[@]}"
if (( vehicle_count != 3 ||
      ${#WINDOW_NAMES[@]} != vehicle_count ||
      ${#INSTANCE_NUMBERS[@]} != vehicle_count ||
      ${#ROUTER_PORTS[@]} != vehicle_count ||
      ${#HOME_LATITUDES[@]} != vehicle_count ||
      ${#HOME_LONGITUDES[@]} != vehicle_count )); then
  echo "Default swarm configuration must define three complete vehicle entries." >&2
  exit 1
fi

if [[ "${VEHICLE_TYPE}" != "ArduPlane" || "${VEHICLE_FRAME}" != "plane" ]]; then
  echo "Default vehicles must use ArduPlane with the fixed-wing plane frame." >&2
  exit 1
fi

if [[ "${SYSTEM_IDS[*]}" != "1 2 3" || "${ROUTER_PORTS[*]}" != "14440 14450 14460" ]]; then
  echo "Default system IDs and MAVLink Router ports do not match the deployment." >&2
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
