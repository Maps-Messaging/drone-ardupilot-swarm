#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="/etc/ardupilot-swarm/ardupilot-swarm.conf"
PURGE=false

if [[ "${1:-}" == "--purge" ]]; then
  PURGE=true
elif [[ -n "${1:-}" ]]; then
  echo "Usage: ./uninstall.sh [--purge]" >&2
  exit 1
fi

ARDUPILOT_DIR=""
if [[ -r "${CONFIG_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${CONFIG_FILE}"
fi

if [[ ${EUID} -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
  sudo -v
fi

"${SUDO[@]}" systemctl disable --now ardupilot-swarm.service 2>/dev/null || true
"${SUDO[@]}" rm -f /etc/systemd/system/ardupilot-swarm.service
"${SUDO[@]}" rm -f /usr/local/bin/start-ardupilot-swarm
"${SUDO[@]}" rm -f /usr/local/bin/stop-ardupilot-swarm
"${SUDO[@]}" rm -f /usr/local/bin/ardupilot-swarm-configure-gcs
"${SUDO[@]}" rm -f /usr/local/bin/ardupilot-swarm-install-parameters
"${SUDO[@]}" rm -f /etc/mavlink-router/config.d/20-ardupilot-swarm.conf
"${SUDO[@]}" rm -f /etc/mavlink-router/config.d/90-ground-controller.conf
"${SUDO[@]}" rm -rf /usr/local/share/ardupilot-swarm

if [[ "${PURGE}" == "true" ]]; then
  "${SUDO[@]}" rm -rf /etc/ardupilot-swarm
  if [[ -n "${ARDUPILOT_DIR}" && -d "${ARDUPILOT_DIR}" ]]; then
    rm -rf "${ARDUPILOT_DIR}"
  fi
  rm -rf "${HOME}/.cache/ardupilot-swarm"
else
  echo "Preserved /etc/ardupilot-swarm and the ArduPilot source tree."
fi

"${SUDO[@]}" systemctl daemon-reload
if systemctl list-unit-files mavlink-router.service >/dev/null 2>&1; then
  "${SUDO[@]}" systemctl restart mavlink-router.service
fi

echo "ArduPilot swarm management files removed."
