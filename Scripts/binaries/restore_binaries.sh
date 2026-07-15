#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/../restore_ravn.sh" \
  "${1:-${SCRIPT_DIR}/restore_binaries.psv}" \
  "${2:-${SCRIPT_DIR}/../../Configs_RaVN}" \
  binaries
