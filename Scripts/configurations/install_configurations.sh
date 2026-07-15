#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/../restore_ravn.sh" \
  "${SCRIPT_DIR}/restore_configurations.psv" \
  "${SCRIPT_DIR}/../../Configs_RaVN" \
  configurations \
  1
