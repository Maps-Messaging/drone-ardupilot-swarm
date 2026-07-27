#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="/etc/ardupilot-swarm/ardupilot-swarm.conf"
SQUID_CONFIG_TARGET="/etc/squid/squid.conf"
SQUID_CONFIG_BACKUP="/etc/squid/squid.conf.pre-ardupilot-swarm"
PURGE=false

if [[ "${1:-}" == "--purge" ]]; then
  PURGE=true
elif [[ -n "${1:-}" ]]; then
  echo "Usage: ./uninstall.sh [--purge]" >&2
  exit 1
fi

ARDUPILOT_DIR=""
MAVLINK_ROUTER_DIR=""
RUN_HOME="${HOME}"
if [[ -r "${CONFIG_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${CONFIG_FILE}"
fi

if [[ ${EUID} -eq 0 ]]; then
  SUDO=()
else
  SUDO=(sudo)
  sudo -n true 2>/dev/null || sudo -v
fi

"${SUDO[@]}" systemctl disable --now ardupilot-swarm.service 2>/dev/null || true
"${SUDO[@]}" rm -f /etc/systemd/system/ardupilot-swarm.service
"${SUDO[@]}" rm -f /usr/local/bin/start-ardupilot-swarm
"${SUDO[@]}" rm -f /usr/local/bin/stop-ardupilot-swarm
"${SUDO[@]}" rm -f /usr/local/bin/ardupilot-swarm-configure-gcs
"${SUDO[@]}" rm -f /usr/local/bin/ardupilot-swarm-install-parameters
"${SUDO[@]}" rm -f /etc/mavlink-router/config.d/20-ardupilot-swarm.conf
"${SUDO[@]}" rm -f /etc/mavlink-router/config.d/30-maps.conf
"${SUDO[@]}" rm -f /etc/mavlink-router/config.d/50-maps.conf
"${SUDO[@]}" rm -f /etc/mavlink-router/config.d/90-ground-controller.conf
"${SUDO[@]}" rm -rf /usr/local/share/ardupilot-swarm

if [[ -e "${SQUID_CONFIG_BACKUP}" ]]; then
  "${SUDO[@]}" mv -f "${SQUID_CONFIG_BACKUP}" "${SQUID_CONFIG_TARGET}"
  if command -v squid >/dev/null 2>&1; then
    "${SUDO[@]}" squid -f "${SQUID_CONFIG_TARGET}" -k parse
  fi
  "${SUDO[@]}" systemctl restart squid.service 2>/dev/null || true
  echo "Restored the previous Squid configuration."
else
  "${SUDO[@]}" rm -f "${SQUID_CONFIG_TARGET}"
  "${SUDO[@]}" systemctl disable --now squid.service 2>/dev/null || true
  echo "Removed the managed Squid configuration and stopped squid.service."
fi

if [[ "${PURGE}" == "true" ]]; then
  "${SUDO[@]}" rm -rf /etc/ardupilot-swarm
  if [[ -n "${ARDUPILOT_DIR}" && -d "${ARDUPILOT_DIR}" ]]; then
    rm -rf "${ARDUPILOT_DIR}"
  fi
  if [[ -n "${MAVLINK_ROUTER_DIR}" && -d "${MAVLINK_ROUTER_DIR}" ]]; then
    rm -rf "${MAVLINK_ROUTER_DIR}"
  fi
  rm -rf "${RUN_HOME}/.cache/ardupilot-swarm"
  rm -rf "${RUN_HOME}/.local/state/ardupilot-swarm"
else
  echo "Preserved /etc/ardupilot-swarm and both upstream source trees."
fi

"${SUDO[@]}" systemctl daemon-reload
if systemctl list-unit-files mavlink-router.service >/dev/null 2>&1; then
  "${SUDO[@]}" systemctl restart mavlink-router.service
fi

echo "ArduPilot swarm management files removed."
