#!/usr/bin/env bash

set -Eeuo pipefail

NEXUS_BASE_URL="${NEXUS_BASE_URL:-https://repository.mapsmessaging.io}"
NEXUS_REPOSITORY="${1:-${NEXUS_REPOSITORY:-maps-drone-repo}}"
PACKAGE_FILE="${2:-}"

usage() {
  cat <<'USAGE'
Usage:
  NEXUS_USER=user NEXUS_PASSWORD=password \
    ./packaging/upload-deb.sh [repository] [package.deb]

Defaults:
  repository: maps-drone-repo
  package:    the single dist/*.deb file
USAGE
}

log() {
  printf '[ardupilot-swarm-release] %s\n' "$*"
}

fail() {
  printf '[ardupilot-swarm-release] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

require_command curl
require_command dpkg-deb
require_command python3

[[ -n "${NEXUS_USER:-}" ]] || fail "NEXUS_USER is required"
[[ -n "${NEXUS_PASSWORD:-}" ]] || fail "NEXUS_PASSWORD is required"
[[ -n "${NEXUS_REPOSITORY}" ]] || fail "Nexus repository is required"

if [[ -z "${PACKAGE_FILE}" ]]; then
  mapfile -t package_files < <(find dist -maxdepth 1 -type f -name '*.deb' -print | sort)
  if [[ ${#package_files[@]} -ne 1 ]]; then
    printf 'Found %d Debian packages under dist:\n' "${#package_files[@]}" >&2
    printf '  %s\n' "${package_files[@]:-}" >&2
    fail "Specify the package file explicitly"
  fi
  PACKAGE_FILE="${package_files[0]}"
fi

[[ -f "${PACKAGE_FILE}" ]] || fail "Package file does not exist: ${PACKAGE_FILE}"

PACKAGE_NAME="$(dpkg-deb -f "${PACKAGE_FILE}" Package)"
PACKAGE_VERSION="$(dpkg-deb -f "${PACKAGE_FILE}" Version)"
SEARCH_FILE="$(mktemp)"
trap 'rm -f "${SEARCH_FILE}"' EXIT

log "Searching ${NEXUS_REPOSITORY} for ${PACKAGE_NAME} ${PACKAGE_VERSION}"
curl \
  --fail \
  --silent \
  --show-error \
  --user "${NEXUS_USER}:${NEXUS_PASSWORD}" \
  --get \
  --data-urlencode "repository=${NEXUS_REPOSITORY}" \
  --data-urlencode "format=apt" \
  --data-urlencode "name=${PACKAGE_NAME}" \
  --data-urlencode "version=${PACKAGE_VERSION}" \
  "${NEXUS_BASE_URL}/service/rest/v1/search" > "${SEARCH_FILE}"

mapfile -t component_ids < <(
  python3 - "${SEARCH_FILE}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    response = json.load(source)

for item in response.get("items", []):
    component_id = item.get("id")
    if component_id:
        print(component_id)
PY
)

for component_id in "${component_ids[@]}"; do
  log "Deleting existing component ${component_id}"
  response_code="$(
    curl \
      --silent \
      --show-error \
      --output /dev/null \
      --write-out '%{http_code}' \
      --user "${NEXUS_USER}:${NEXUS_PASSWORD}" \
      --request DELETE \
      "${NEXUS_BASE_URL}/service/rest/v1/components/${component_id}"
  )"

  [[ "${response_code}" == "204" ]] || fail "Nexus component deletion returned HTTP ${response_code}"
done

log "Uploading ${PACKAGE_FILE} to ${NEXUS_REPOSITORY}"
curl \
  --fail \
  --show-error \
  --silent \
  --user "${NEXUS_USER}:${NEXUS_PASSWORD}" \
  --header 'Content-Type: multipart/form-data' \
  --data-binary "@${PACKAGE_FILE}" \
  "${NEXUS_BASE_URL}/repository/${NEXUS_REPOSITORY}/"

log "Published ${PACKAGE_NAME} ${PACKAGE_VERSION}"
