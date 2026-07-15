#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_INSTALLER="${SCRIPT_DIR}/../install_pkg.sh"
PACKAGE_LIST="${SCRIPT_DIR}/../pkg_core.lst"

if [[ ! -x $PACKAGE_INSTALLER ]]; then
  echo "Applications installer not found: ${PACKAGE_INSTALLER}" >&2
  exit 1
fi

case "${1:-test}" in
  test | --test)
    flg_DryRun=1 bash "$PACKAGE_INSTALLER" "$PACKAGE_LIST"
    ;;
  install | --install)
    bash "$PACKAGE_INSTALLER" "$PACKAGE_LIST"
    ;;
  dry-run | --dry-run)
    flg_DryRun=1 bash "$PACKAGE_INSTALLER" "$PACKAGE_LIST"
    ;;
  help | --help | -h)
    printf '%s\n' "Usage: manage_applications.sh [test|install|dry-run|help]"
    ;;
  *)
    printf 'Unknown command: %s\n' "$1" >&2
    exit 2
    ;;
esac
