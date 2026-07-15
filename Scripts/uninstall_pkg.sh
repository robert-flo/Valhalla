#!/usr/bin/env bash

set -Eeuo pipefail

scrDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
listPkg="${1:-}"

if [[ -z $listPkg || ! -f $listPkg ]]; then
  printf 'Usage: %s RUN_FILE\n' "${0##*/}" >&2
  exit 2
fi

# shellcheck disable=SC1091
source "${scrDir}/global_fn.sh"

removed=0
skipped=0
print_section "⏳  Removiendo paquetes"
print_info "🔒  Solo se afectarán los paquetes registrados en esta corrida"
echo ""
while IFS= read -r pkg; do
  pkg="${pkg%%#*}"
  pkg="${pkg//[[:space:]]/}"
  [[ -n $pkg ]] || continue
  if pacman -Q "$pkg" &> /dev/null; then
    print_success "$pkg"
    sudo pacman -R --noconfirm "$pkg" 2>&1 | sed 's/^/     │ /'
    count_ok "$pkg"
    ((removed += 1))
  else
    print_info "–  Ya estaba ausente: $pkg"
    count_skip "$pkg"
    ((skipped += 1))
  fi
done < "$listPkg"
echo -e "${GRAY}  ──────────────────────────────────────────────────────────${NC}"
print_section "📋  Resultado del rollback"
if ((removed == 0)); then
  print_success "Rollback no requerido — $skipped ya estaban ausentes"
else
  if ((removed == 1)); then removed_label="paquete removido"; else removed_label="paquetes removidos"; fi
  if ((skipped == 1)); then skipped_label="1 ya estaba ausente"; else skipped_label="$skipped ya estaban ausentes"; fi
  print_success "Rollback completo — $removed $removed_label, $skipped_label"
fi
print_info "Detalle: $listPkg"
print_summary "Application rollback"
