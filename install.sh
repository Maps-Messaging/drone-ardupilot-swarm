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
REF_SET=false
DIR_SET=false
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
  --ref REF                 ArduPilot branch, tag or commit. Default: master
  --ardupilot-dir DIRECTORY Clone/build directory. Default: $HOME/ardupilot
  --refresh-prerequisites   Run ArduPilot's prerequisite installer again
  --skip-build              Install management files without building ArduPilot
  --update                  Update an existing installation
  -h, --help                Show this help

Run this script as the account that will own and run ArduPilot, not with sudo.
The script uses sudo only for packages and system files.
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --ref)
      ARDUPILOT_REF="${2:?Missing value for --ref}"
      REF_SET=true
      shift 2
      ;;
    --ardupilot-dir)
      ARDUPILOT_DIR="${2:?Missing value for --ardupilot-dir}"
      DIR_SET=true
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
REQUESTED_REF="${ARDUPILOT_REF}"
REQUESTED_DIR="${ARDUPILOT_DIR}"

if [[ -r "${CONFIG_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${CONFIG_FILE}"

  if [[ "${RUN_USER}" != "$(id -un)" ]]; then
    echo "The existing installation belongs to ${RUN_USER}; run the update as that user." >&2
    exit 1
  fi

  if [[ "${REF_SET}" == "true" ]]; then
    ARDUPILOT_REF="${REQUESTED_REF}"
  fi
  if [[ "${DIR_SET}" == "true" ]]; then
    ARDUPILOT_DIR="${REQUESTED_DIR}"
  fi
fi

ARDUPILOT_DIR="$(realpath -m "${ARDUPILOT_DIR}")"
SERVICE_WAS_ACTIVE=false

if systemctl is-active --quiet ardupilot-swarm.service 2>/dev/null; then
  SERVICE_WAS_ACTIVE=true
fi

sudo -v

if [[ "${SERVICE_WAS_ACTIVE}" == "true" ]]; then
  sudo systemctl stop ardupilot-swarm.service
fi

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git tmux mavlink-router

if [[ ! -d "${ARDUPILOT_DIR}/.git" ]]; then
  if [[ -e "${ARDUPILOT_DIR}" ]]; then
    echo "ArduPilot directory exists but is not a Git repository: ${ARDUPILOT_DIR}" >&2
    exit 1
  fi
  git clone --recursive "${ARDUPILOT_REPOSITORY}" "${ARDUPILOT_DIR}"
else
  if [[ -n "$(git -C "${ARDUPILOT_DIR}" status --porcelain)" ]]; then
    echo "ArduPilot working tree contains local changes: ${ARDUPILOT_DIR}" >&2
    echo "Commit, stash or remove those changes before updating." >&2
    exit 1
  fi
fi

git -C "${ARDUPILOT_DIR}" fetch --tags --prune origin

if git -C "${ARDUPILOT_DIR}" show-ref --verify --quiet "refs/remotes/origin/${ARDUPILOT_REF}"; then
  git -C "${ARDUPILOT_DIR}" checkout -B "${ARDUPILOT_REF}" "origin/${ARDUPILOT_REF}"
else
  git -C "${ARDUPILOT_DIR}" checkout --detach "${ARDUPILOT_REF}"
fi

git -C "${ARDUPILOT_DIR}" submodule sync --recursive
git -C "${ARDUPILOT_DIR}" submodule update --init --recursive

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
    "${PROJECT_DIR}/config/ardupilot-swarm.conf.example" > "${TEMP_CONFIG}"

  sudo install -m 0644 -o root -g root "${TEMP_CONFIG}" "${CONFIG_FILE}"
else
  echo "Preserving existing runtime configuration: ${CONFIG_FILE}"

  update_config_value() {
    local key="$1"
    local value="$2"
    local escaped_value
    escaped_value="$(printf '%s' "${value}" | sed 's/[&|]/\\&/g')"
    sudo sed -i "s|^${key}=.*|${key}=\"${escaped_value}\"|" "${CONFIG_FILE}"
  }

  if [[ "${REF_SET}" == "true" ]]; then
    update_config_value ARDUPILOT_REF "${ARDUPILOT_REF}"
  fi
  if [[ "${DIR_SET}" == "true" ]]; then
    update_config_value ARDUPILOT_DIR "${ARDUPILOT_DIR}"
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

ArduPilot source: ${ARDUPILOT_DIR}
ArduPilot ref:    ${ARDUPILOT_REF}
Runtime config:   ${CONFIG_FILE}
Parameter file:   ${PARAM_FILE}
Router endpoint:  ${ROUTER_ADDRESS}:${ROUTER_PORT}

Next steps:
  sudo ardupilot-swarm-install-parameters /path/to/drone.parm
  sudo ardupilot-swarm-configure-gcs GROUND_CONTROLLER_ADDRESS 14550
  sudo systemctl start ardupilot-swarm.service
EOF_SUMMARY
