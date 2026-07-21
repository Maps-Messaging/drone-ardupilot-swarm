#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/etc/ardupilot-swarm"
CONFIG_FILE="${CONFIG_DIR}/ardupilot-swarm.conf"
ROUTER_DIR="/etc/mavlink-router"
ROUTER_DROPIN_DIR="${ROUTER_DIR}/config.d"
ROUTER_ENDPOINT_FILE="${ROUTER_DROPIN_DIR}/20-ardupilot-swarm.conf"
SERVICE_FILE="/etc/systemd/system/ardupilot-swarm.service"
SHARE_DIR="/usr/local/share/ardupilot-swarm"

ARDUPILOT_REPOSITORY="https://github.com/ArduPilot/ardupilot.git"
ARDUPILOT_REF="master"
ARDUPILOT_DIR="${HOME}/ardupilot"
ARDUPILOT_BUILD_TARGET="plane"

MAVLINK_ROUTER_REPOSITORY="https://github.com/mavlink-router/mavlink-router.git"
MAVLINK_ROUTER_REF="v4"
MAVLINK_ROUTER_DIR="${HOME}/mavlink-router"

ARDUPILOT_REF_SET=false
ARDUPILOT_DIR_SET=false
MAVLINK_ROUTER_REF_SET=false
MAVLINK_ROUTER_DIR_SET=false
REFRESH_PREREQUISITES=false
SKIP_BUILD=false
TEMP_CONFIG=""
TEMP_SERVICE=""
TEMP_ROUTER=""
trap 'rm -f "${TEMP_CONFIG}" "${TEMP_SERVICE}" "${TEMP_ROUTER}"' EXIT

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

Options:
  --ref REF                         ArduPilot branch, tag or commit. Default: master
  --ardupilot-dir DIRECTORY         ArduPilot clone/build directory. Default: $HOME/ardupilot
  --mavlink-router-ref REF          MAVLink Router branch, tag or commit. Default: v4
  --mavlink-router-dir DIRECTORY    MAVLink Router clone/build directory. Default: $HOME/mavlink-router
  --refresh-prerequisites           Run ArduPilot's prerequisite installer again
  --skip-build                      Install management files without rebuilding ArduPilot
  --update                          Update an existing installation
  -h, --help                        Show this help

Run this script as the account that will own and run ArduPilot, not with sudo.
The script uses sudo only for packages, source installation and system files.
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --ref)
      ARDUPILOT_REF="${2:?Missing value for --ref}"
      ARDUPILOT_REF_SET=true
      shift 2
      ;;
    --ardupilot-dir)
      ARDUPILOT_DIR="${2:?Missing value for --ardupilot-dir}"
      ARDUPILOT_DIR_SET=true
      shift 2
      ;;
    --mavlink-router-ref)
      MAVLINK_ROUTER_REF="${2:?Missing value for --mavlink-router-ref}"
      MAVLINK_ROUTER_REF_SET=true
      shift 2
      ;;
    --mavlink-router-dir)
      MAVLINK_ROUTER_DIR="${2:?Missing value for --mavlink-router-dir}"
      MAVLINK_ROUTER_DIR_SET=true
      shift 2
      ;;
    --refresh-prerequisites)
      REFRESH_PREREQUISITES=true
      shift
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --update)
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ${EUID} -eq 0 ]]; then
  echo "Run this installer as the account that will run ArduPilot, without sudo." >&2
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  echo "This installer requires a Debian or Ubuntu system." >&2
  exit 1
fi

# shellcheck source=/dev/null
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" && "${ID:-}" != "debian" && "${ID_LIKE:-}" != *debian* ]]; then
  echo "Unsupported operating system: ${PRETTY_NAME:-unknown}" >&2
  exit 1
fi

RUN_USER="$(id -un)"
RUN_GROUP="$(id -gn)"
RUN_HOME="${HOME}"
REQUESTED_ARDUPILOT_REF="${ARDUPILOT_REF}"
REQUESTED_ARDUPILOT_DIR="${ARDUPILOT_DIR}"
REQUESTED_MAVLINK_ROUTER_REF="${MAVLINK_ROUTER_REF}"
REQUESTED_MAVLINK_ROUTER_DIR="${MAVLINK_ROUTER_DIR}"

if [[ -r "${CONFIG_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${CONFIG_FILE}"

  if [[ "${RUN_USER}" != "$(id -un)" ]]; then
    echo "The existing installation belongs to ${RUN_USER}; run the update as that user." >&2
    exit 1
  fi

  if [[ "${ARDUPILOT_REF_SET}" == "true" ]]; then
    ARDUPILOT_REF="${REQUESTED_ARDUPILOT_REF}"
  fi
  if [[ "${ARDUPILOT_DIR_SET}" == "true" ]]; then
    ARDUPILOT_DIR="${REQUESTED_ARDUPILOT_DIR}"
  fi
  if [[ "${MAVLINK_ROUTER_REF_SET}" == "true" ]]; then
    MAVLINK_ROUTER_REF="${REQUESTED_MAVLINK_ROUTER_REF}"
  fi
  if [[ "${MAVLINK_ROUTER_DIR_SET}" == "true" ]]; then
    MAVLINK_ROUTER_DIR="${REQUESTED_MAVLINK_ROUTER_DIR}"
  fi
fi

ARDUPILOT_DIR="$(realpath -m "${ARDUPILOT_DIR}")"
MAVLINK_ROUTER_DIR="$(realpath -m "${MAVLINK_ROUTER_DIR}")"
MAVLINK_ROUTER_BUILD_DIR="${RUN_HOME}/.cache/ardupilot-swarm/mavlink-router-build"
SERVICE_WAS_ACTIVE=false

if systemctl is-active --quiet ardupilot-swarm.service 2>/dev/null; then
  SERVICE_WAS_ACTIVE=true
fi

sudo -v

if [[ "${SERVICE_WAS_ACTIVE}" == "true" ]]; then
  sudo systemctl stop ardupilot-swarm.service
fi

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git \
  tmux \
  meson \
  ninja-build \
  pkg-config \
  gcc \
  g++ \
  systemd

checkout_repository() {
  local repository="$1"
  local reference="$2"
  local directory="$3"
  local name="$4"

  if [[ ! -d "${directory}/.git" ]]; then
    if [[ -e "${directory}" ]]; then
      echo "${name} directory exists but is not a Git repository: ${directory}" >&2
      exit 1
    fi
    git clone --recursive "${repository}" "${directory}"
  elif [[ -n "$(git -C "${directory}" status --porcelain)" ]]; then
    echo "${name} working tree contains local changes: ${directory}" >&2
    echo "Commit, stash or remove those changes before updating." >&2
    exit 1
  fi

  git -C "${directory}" fetch --tags --prune origin

  if git -C "${directory}" show-ref --verify --quiet "refs/remotes/origin/${reference}"; then
    git -C "${directory}" checkout -B "${reference}" "origin/${reference}"
  else
    git -C "${directory}" checkout --detach "${reference}"
  fi

  git -C "${directory}" submodule sync --recursive
  git -C "${directory}" submodule update --init --recursive
}

checkout_repository \
  "${MAVLINK_ROUTER_REPOSITORY}" \
  "${MAVLINK_ROUTER_REF}" \
  "${MAVLINK_ROUTER_DIR}" \
  "MAVLink Router"

rm -rf "${MAVLINK_ROUTER_BUILD_DIR}"
mkdir -p "${MAVLINK_ROUTER_BUILD_DIR}"
meson setup \
  --buildtype=release \
  "${MAVLINK_ROUTER_BUILD_DIR}" \
  "${MAVLINK_ROUTER_DIR}"

ninja -C "${MAVLINK_ROUTER_BUILD_DIR}"
sudo ninja -C "${MAVLINK_ROUTER_BUILD_DIR}" install
sudo systemctl daemon-reload
hash -r

if ! command -v mavlink-routerd >/dev/null 2>&1 && [[ ! -x /usr/local/bin/mavlink-routerd ]]; then
  echo "MAVLink Router installed, but mavlink-routerd was not found." >&2
  exit 1
fi

if ! systemctl cat mavlink-router.service >/dev/null 2>&1; then
  echo "MAVLink Router installed, but mavlink-router.service was not found." >&2
  exit 1
fi

checkout_repository \
  "${ARDUPILOT_REPOSITORY}" \
  "${ARDUPILOT_REF}" \
  "${ARDUPILOT_DIR}" \
  "ArduPilot"

PREREQUISITE_STATE_DIR="${RUN_HOME}/.cache/ardupilot-swarm"
PREREQUISITE_MARKER="${PREREQUISITE_STATE_DIR}/prerequisites-installed"
if [[ ! -f "${PREREQUISITE_MARKER}" || "${REFRESH_PREREQUISITES}" == "true" ]]; then
  "${ARDUPILOT_DIR}/Tools/environment_install/install-prereqs-ubuntu.sh" -y
  mkdir -p "${PREREQUISITE_STATE_DIR}"
  touch "${PREREQUISITE_MARKER}"
fi

if [[ "${SKIP_BUILD}" == "false" ]]; then
  (
    cd "${ARDUPILOT_DIR}"
    ./waf configure --board sitl
    ./waf "${ARDUPILOT_BUILD_TARGET}"
  )
fi

sudo install -d -m 0755 -o root -g root "${CONFIG_DIR}"
sudo install -d -m 0755 -o root -g root "${ROUTER_DIR}" "${ROUTER_DROPIN_DIR}"
sudo install -d -m 0755 -o root -g root "${SHARE_DIR}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  TEMP_CONFIG="$(mktemp)"

  sed \
    -e "s|@RUN_USER@|${RUN_USER}|g" \
    -e "s|@RUN_GROUP@|${RUN_GROUP}|g" \
    -e "s|@RUN_HOME@|${RUN_HOME}|g" \
    -e "s|@ARDUPILOT_REF@|${ARDUPILOT_REF}|g" \
    -e "s|@ARDUPILOT_DIR@|${ARDUPILOT_DIR}|g" \
    -e "s|@MAVLINK_ROUTER_REF@|${MAVLINK_ROUTER_REF}|g" \
    -e "s|@MAVLINK_ROUTER_DIR@|${MAVLINK_ROUTER_DIR}|g" \
    "${PROJECT_DIR}/config/ardupilot-swarm.conf.example" > "${TEMP_CONFIG}"

  sudo install -m 0644 -o root -g root "${TEMP_CONFIG}" "${CONFIG_FILE}"
else
  echo "Preserving existing runtime configuration: ${CONFIG_FILE}"

  set_config_value() {
    local key="$1"
    local value="$2"
    local escaped_value
    escaped_value="$(printf '%s' "${value}" | sed 's/[&|]/\\&/g')"

    if grep -q "^${key}=" "${CONFIG_FILE}"; then
      sudo sed -i "s|^${key}=.*|${key}=\"${escaped_value}\"|" "${CONFIG_FILE}"
    else
      printf '%s="%s"\n' "${key}" "${value}" | sudo tee -a "${CONFIG_FILE}" >/dev/null
    fi
  }

  if [[ "${ARDUPILOT_REF_SET}" == "true" ]]; then
    set_config_value ARDUPILOT_REF "${ARDUPILOT_REF}"
  fi
  if [[ "${ARDUPILOT_DIR_SET}" == "true" ]]; then
    set_config_value ARDUPILOT_DIR "${ARDUPILOT_DIR}"
  fi
  if [[ "${MAVLINK_ROUTER_REF_SET}" == "true" ]]; then
    set_config_value MAVLINK_ROUTER_REF "${MAVLINK_ROUTER_REF}"
  fi
  if [[ "${MAVLINK_ROUTER_DIR_SET}" == "true" ]]; then
    set_config_value MAVLINK_ROUTER_DIR "${MAVLINK_ROUTER_DIR}"
  fi

  if ! grep -q '^MAVLINK_ROUTER_REPOSITORY=' "${CONFIG_FILE}"; then
    set_config_value MAVLINK_ROUTER_REPOSITORY "${MAVLINK_ROUTER_REPOSITORY}"
  fi
  if ! grep -q '^MAVLINK_ROUTER_REF=' "${CONFIG_FILE}"; then
    set_config_value MAVLINK_ROUTER_REF "${MAVLINK_ROUTER_REF}"
  fi
  if ! grep -q '^MAVLINK_ROUTER_DIR=' "${CONFIG_FILE}"; then
    set_config_value MAVLINK_ROUTER_DIR "${MAVLINK_ROUTER_DIR}"
  fi
fi

# Reload the installed values, including any deployment-specific edits.
# shellcheck source=/dev/null
source "${CONFIG_FILE}"

TEMP_SERVICE="$(mktemp)"
sed \
  -e "s|@RUN_USER@|${RUN_USER}|g" \
  -e "s|@RUN_GROUP@|${RUN_GROUP}|g" \
  -e "s|@RUN_HOME@|${RUN_HOME}|g" \
  "${PROJECT_DIR}/systemd/ardupilot-swarm.service.in" > "${TEMP_SERVICE}"
sudo install -m 0644 -o root -g root "${TEMP_SERVICE}" "${SERVICE_FILE}"

TEMP_ROUTER="$(mktemp)"
sed \
  -e "s|@ROUTER_ADDRESS@|${ROUTER_ADDRESS}|g" \
  -e "s|@ROUTER_PORT@|${ROUTER_PORT}|g" \
  "${PROJECT_DIR}/config/mavlink-router-ardupilot.conf.in" > "${TEMP_ROUTER}"
sudo install -m 0644 -o root -g root "${TEMP_ROUTER}" "${ROUTER_ENDPOINT_FILE}"

if [[ ! -f "${ROUTER_DIR}/main.conf" ]]; then
  sudo install -m 0644 -o root -g root \
    "${PROJECT_DIR}/config/mavlink-router-main.conf" \
    "${ROUTER_DIR}/main.conf"
else
  echo "Preserving existing MAVLink router configuration: ${ROUTER_DIR}/main.conf"
fi

sudo install -m 0755 -o root -g root "${PROJECT_DIR}/scripts/start-ardupilot-swarm" /usr/local/bin/start-ardupilot-swarm
sudo install -m 0755 -o root -g root "${PROJECT_DIR}/scripts/stop-ardupilot-swarm" /usr/local/bin/stop-ardupilot-swarm
sudo install -m 0755 -o root -g root "${PROJECT_DIR}/scripts/ardupilot-swarm-configure-gcs" /usr/local/bin/ardupilot-swarm-configure-gcs
sudo install -m 0755 -o root -g root "${PROJECT_DIR}/scripts/ardupilot-swarm-install-parameters" /usr/local/bin/ardupilot-swarm-install-parameters
sudo install -m 0644 -o root -g root "${PROJECT_DIR}/config/ground-controller.conf.example" "${SHARE_DIR}/ground-controller.conf.example"
sudo install -m 0644 -o root -g root "${PROJECT_DIR}/config/ardupilot-swarm.conf.example" "${SHARE_DIR}/ardupilot-swarm.conf.example"

sudo systemctl daemon-reload
sudo systemctl enable ardupilot-swarm.service
sudo systemctl enable --now mavlink-router.service
sudo systemctl restart mavlink-router.service

if [[ "${SERVICE_WAS_ACTIVE}" == "true" && -r "${PARAM_FILE}" ]]; then
  sudo systemctl start ardupilot-swarm.service
fi

cat <<EOF_SUMMARY

Installation complete.

MAVLink Router source: ${MAVLINK_ROUTER_DIR}
MAVLink Router ref:    ${MAVLINK_ROUTER_REF}
ArduPilot source:      ${ARDUPILOT_DIR}
ArduPilot ref:         ${ARDUPILOT_REF}
Runtime config:        ${CONFIG_FILE}
Parameter file:        ${PARAM_FILE}
Router endpoint:       ${ROUTER_ADDRESS}:${ROUTER_PORT}

Next steps:
  sudo ardupilot-swarm-install-parameters /path/to/drone.parm
  sudo ardupilot-swarm-configure-gcs GROUND_CONTROLLER_ADDRESS 14550
  sudo systemctl start ardupilot-swarm.service
EOF_SUMMARY
