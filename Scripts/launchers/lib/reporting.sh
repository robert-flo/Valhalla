#!/usr/bin/env bash

APPS_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/applications/icons"

declare -a RAVN_CREATED=()
declare -a RAVN_UPDATED=()
declare -a RAVN_FAILED=()

ravn_launchers_reset() {
  RAVN_CREATED=()
  RAVN_UPDATED=()
  RAVN_FAILED=()
}

_ravn_resolve_icon_ref() {
  local icon_ref="$1"

  if [[ $icon_ref == /* ]]; then
    printf '%s' "$icon_ref"
  elif [[ $icon_ref =~ ^https?:// ]]; then
    printf '%s' "$icon_ref"
  elif [[ $icon_ref == *.* ]]; then
    printf '%s' "${ICON_DIR}/${icon_ref}"
  else
    printf '%s' "$icon_ref"
  fi
}

_ravn_validate_icon() {
  local icon_ref="$1"
  local resolved

  resolved="$(_ravn_resolve_icon_ref "$icon_ref")"
  if [[ $resolved =~ ^https?:// ]]; then
    return 0
  fi
  if [[ $resolved == */* || $resolved == *.* ]]; then
    [[ -f $resolved ]]
    return
  fi
  return 0
}

_ravn_record_result() {
  local kind="$1"
  local name="$2"
  local desktop="${APPS_DIR}/${name}.desktop"

  if [[ -f $desktop ]]; then
    if [[ $kind == updated ]]; then
      RAVN_UPDATED+=("$name")
    else
      RAVN_CREATED+=("$name")
    fi
    return 0
  fi

  RAVN_FAILED+=("$name")
  return 1
}

ravn_webapp_install() {
  local name="$1"
  local icon_ref="${3:-}"
  local existed=0
  [[ -f "${APPS_DIR}/${name}.desktop" ]] && existed=1

  if [[ -n $icon_ref ]] && ! _ravn_validate_icon "$icon_ref"; then
    RAVN_FAILED+=("$name (icono no encontrado: $icon_ref)")
    return 1
  fi

  if omarchy-webapp-install "$@"; then
    if (( existed )); then
      _ravn_record_result updated "$name"
    else
      _ravn_record_result created "$name"
    fi
  else
    RAVN_FAILED+=("$name")
    return 1
  fi
}

ravn_tui_install() {
  local name="$1"
  local icon_ref="${4:-}"
  local existed=0
  [[ -f "${APPS_DIR}/${name}.desktop" ]] && existed=1

  if [[ -n $icon_ref ]] && ! _ravn_validate_icon "$icon_ref"; then
    RAVN_FAILED+=("$name (icono no encontrado: $icon_ref)")
    return 1
  fi

  if omarchy-tui-install "$@"; then
    if (( existed )); then
      _ravn_record_result updated "$name"
    else
      _ravn_record_result created "$name"
    fi
  else
    RAVN_FAILED+=("$name")
    return 1
  fi
}

ravn_launcher_install() {
  local name="$1"
  local icon_ref="${3:-}"
  local existed=0
  [[ -f "${APPS_DIR}/${name}.desktop" ]] && existed=1

  if [[ -n $icon_ref ]] && ! _ravn_validate_icon "$icon_ref"; then
    RAVN_FAILED+=("$name (icono no encontrado: $icon_ref)")
    return 1
  fi

  if omarchy-launcher-install "$@"; then
    if (( existed )); then
      _ravn_record_result updated "$name"
    else
      _ravn_record_result created "$name"
    fi
  else
    RAVN_FAILED+=("$name")
    return 1
  fi
}

ravn_browser_webapp_install() {
  local name="$1"
  local icon_ref="${3:-}"
  local browser="${4:-${RAVN_ALT_BROWSER:-microsoft-edge-stable}}"
  local existed=0
  [[ -f "${APPS_DIR}/${name}.desktop" ]] && existed=1

  if [[ -n $icon_ref ]] && ! _ravn_validate_icon "$icon_ref"; then
    RAVN_FAILED+=("$name (icono no encontrado: $icon_ref)")
    return 1
  fi

  if ! command -v "$browser" &>/dev/null; then
    RAVN_FAILED+=("$name (navegador no encontrado: $browser)")
    return 1
  fi

  if ravn-browser-webapp-install "$@"; then
    if (( existed )); then
      _ravn_record_result updated "$name"
    else
      _ravn_record_result created "$name"
    fi
  else
    RAVN_FAILED+=("$name")
    return 1
  fi
}

_ravn_print_group() {
  local label="$1"
  local marker="$2"
  shift 2
  local -a items=("$@")

  echo "[launchers] ${label} (${#items[@]}):"
  if ((${#items[@]} == 0)); then
    echo "  (ninguno)"
    return
  fi

  local item
  for item in "${items[@]}"; do
    echo "  ${marker} ${item}"
  done
}

ravn_launchers_summary() {
  local total=$(( ${#RAVN_CREATED[@]} + ${#RAVN_UPDATED[@]} + ${#RAVN_FAILED[@]} ))

  echo ""
  echo "[launchers] resumen (${total} procesados)"
  _ravn_print_group "creados" "✓" "${RAVN_CREATED[@]}"
  _ravn_print_group "actualizados" "↻" "${RAVN_UPDATED[@]}"
  _ravn_print_group "fallidos" "✗" "${RAVN_FAILED[@]}"

  if ((${#RAVN_FAILED[@]} > 0)); then
    echo ""
    echo "[launchers] error: ${#RAVN_FAILED[@]} lanzador(es) no se instalaron"
    return 1
  fi

  echo ""
  echo "[launchers] done (${#RAVN_CREATED[@]} creados, ${#RAVN_UPDATED[@]} actualizados)"
  return 0
}