#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${SCRIPT_DIR}/restore_binaries.psv"
SOURCE_DIR="${SCRIPT_DIR}/../../Configs_RaVN"
RESTORE_SCRIPT="${SCRIPT_DIR}/restore_binaries.sh"

if [[ ! -f $RESTORE_SCRIPT || ! -d $SOURCE_DIR ]]; then
  echo "[binaries] error: restore sources are unavailable" >&2
  exit 1
fi

flg_DryRun=0 bash "$RESTORE_SCRIPT" "$MANIFEST" "$SOURCE_DIR"
echo "[binaries] installed declared RaVN binaries"
