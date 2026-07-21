#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/build/debian}"
PACKAGE_ROOT="${BUILD_DIR}/package-root"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/dist}"

PACKAGE_NAME="${PACKAGE_NAME:-ardupilot-swarm}"
PACKAGE_VERSION="${PACKAGE_VERSION:-$(<"${ROOT_DIR}/VERSION")}"
PACKAGE_ARCHITECTURE="${PACKAGE_ARCHITECTURE:-all}"
PACKAGE_MAINTAINER="${PACKAGE_MAINTAINER:-Matthew Buckton <matthew@buckton.org>}"
PACKAGE_SECTION="${PACKAGE_SECTION:-misc}"
PACKAGE_PRIORITY="${PACKAGE_PRIORITY:-optional}"
PACKAGE_DEPENDS="${PACKAGE_DEPENDS:-bash, git, sudo, tmux, mavlink-router, systemd, coreutils, sed, grep}"

log() {
  printf '[ardupilot-swarm-package] %s\n' "$*"
}

fail() {
  printf '[ardupilot-swarm-package] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

validate_package_version() {
  case "${PACKAGE_VERSION}" in
    '' | *:* | */* | *' '*)
      fail "Invalid Debian package version: ${PACKAGE_VERSION}"
      ;;
  esac
}

copy_project() {
  local destination="$1"

  install -m 0755 "${ROOT_DIR}/install.sh" "${destination}/install.sh"
  install -m 0755 "${ROOT_DIR}/update.sh" "${destination}/update.sh"
  install -m 0755 "${ROOT_DIR}/uninstall.sh" "${destination}/uninstall.sh"
  install -m 0644 "${ROOT_DIR}/VERSION" "${destination}/VERSION"

  cp -a "${ROOT_DIR}/config" "${destination}/config"
  cp -a "${ROOT_DIR}/scripts" "${destination}/scripts"
  cp -a "${ROOT_DIR}/systemd" "${destination}/systemd"

  rm -f "${destination}/scripts/validate.sh"
}

write_control_file() {
  local control_file="$1"
  local installed_size="$2"

  cat > "${control_file}" <<EOF_CONTROL
Package: ${PACKAGE_NAME}
Version: ${PACKAGE_VERSION}
Section: ${PACKAGE_SECTION}
Priority: ${PACKAGE_PRIORITY}
Architecture: ${PACKAGE_ARCHITECTURE}
Maintainer: ${PACKAGE_MAINTAINER}
Installed-Size: ${installed_size}
Depends: ${PACKAGE_DEPENDS}
Description: ArduPilot SITL swarm host installer
 Installs the standalone management project used to clone and build ArduPilot,
 install mavlink-router, install the swarm start and stop scripts, and configure
 the systemd service. Deployment-specific GCS and parameter files remain external.
EOF_CONTROL
}

require_command dpkg-deb
require_command install
require_command find
require_command du
require_command awk
require_command sha256sum

validate_package_version
"${ROOT_DIR}/scripts/validate.sh"

rm -rf "${BUILD_DIR}"
mkdir -p "${PACKAGE_ROOT}/DEBIAN" "${PACKAGE_ROOT}/usr/share/ardupilot-swarm" "${PACKAGE_ROOT}/usr/share/doc/${PACKAGE_NAME}" "${PACKAGE_ROOT}/usr/bin" "${OUTPUT_DIR}"

copy_project "${PACKAGE_ROOT}/usr/share/ardupilot-swarm"

install -m 0755 "${ROOT_DIR}/packaging/wrappers/ardupilot-swarm-install" "${PACKAGE_ROOT}/usr/bin/ardupilot-swarm-install"
install -m 0755 "${ROOT_DIR}/packaging/wrappers/ardupilot-swarm-update" "${PACKAGE_ROOT}/usr/bin/ardupilot-swarm-update"
install -m 0755 "${ROOT_DIR}/packaging/wrappers/ardupilot-swarm-uninstall" "${PACKAGE_ROOT}/usr/bin/ardupilot-swarm-uninstall"
install -m 0755 "${ROOT_DIR}/packaging/debian/postinst" "${PACKAGE_ROOT}/DEBIAN/postinst"
install -m 0644 "${ROOT_DIR}/packaging/debian/copyright" "${PACKAGE_ROOT}/usr/share/doc/${PACKAGE_NAME}/copyright"
install -m 0644 "${ROOT_DIR}/packaging/debian/README.Debian" "${PACKAGE_ROOT}/usr/share/doc/${PACKAGE_NAME}/README.Debian"

find "${PACKAGE_ROOT}/usr/share/ardupilot-swarm" -type d -exec chmod 0755 {} +
find "${PACKAGE_ROOT}/usr/share/ardupilot-swarm" -type f -exec chmod 0644 {} +
find "${PACKAGE_ROOT}/usr/share/ardupilot-swarm" -type f \( -name '*.sh' -o -path '*/scripts/*' -o -name 'install.sh' -o -name 'update.sh' -o -name 'uninstall.sh' \) -exec chmod 0755 {} +

BUILD_TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
cat > "${PACKAGE_ROOT}/usr/share/doc/${PACKAGE_NAME}/build-manifest.txt" <<EOF_MANIFEST
package.name=${PACKAGE_NAME}
package.version=${PACKAGE_VERSION}
package.architecture=${PACKAGE_ARCHITECTURE}
build.timestamp=${BUILD_TIMESTAMP}
buildkite.build.number=${BUILDKITE_BUILD_NUMBER:-}
buildkite.build.url=${BUILDKITE_BUILD_URL:-}
git.commit=$(git -C "${ROOT_DIR}" rev-parse HEAD 2>/dev/null || true)
EOF_MANIFEST

INSTALLED_SIZE="$(du -sk "${PACKAGE_ROOT}" | awk '{print $1}')"
write_control_file "${PACKAGE_ROOT}/DEBIAN/control" "${INSTALLED_SIZE}"
chmod 0644 "${PACKAGE_ROOT}/DEBIAN/control"

PACKAGE_FILE="${OUTPUT_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${PACKAGE_ARCHITECTURE}.deb"
rm -f "${PACKAGE_FILE}" "${PACKAGE_FILE}.sha256"

log "Building ${PACKAGE_FILE}"
dpkg-deb --build --root-owner-group "${PACKAGE_ROOT}" "${PACKAGE_FILE}"
sha256sum "${PACKAGE_FILE}" > "${PACKAGE_FILE}.sha256"
dpkg-deb --info "${PACKAGE_FILE}"
log "Built ${PACKAGE_FILE}"
