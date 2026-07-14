#!/usr/bin/env bash

# Prevent duplicate loading when this library is sourced more than once.
if [[ ${_GLOBAL_FN_SOURCED:-0} -eq 1 ]]; then
  # shellcheck disable=SC2317
  return 0 2> /dev/null || exit 0
fi
readonly _GLOBAL_FN_SOURCED=1

# ╭──────────────────────────────────────────────────────────────────────────────╮
# │                                                                              │
# │                        Global Functions & Variables                          │
# │                         Reusable Shell Script Utils                          │
# │                                                                              │
# ╰──────────────────────────────────────────────────────────────────────────────╯

# shellcheck disable=SC2034

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Colors & Styling                                                             │
# └──────────────────────────────────────────────────────────────────────────────┘

# Colors and icons use a terminal-friendly presentation by default. Disable
# styling automatically for pipes, Docker/CI output, dumb terminals, or when
# the caller explicitly requests the NO_COLOR convention.
if [[ -t 1 && ${TERM:-dumb} != "dumb" && -z ${NO_COLOR:-} ]]; then
  readonly RED=$'\033[0;31m'
  readonly GREEN=$'\033[0;32m'
  readonly YELLOW=$'\033[0;33m'
  readonly BLUE=$'\033[0;34m'
  readonly MAGENTA=$'\033[0;35m'
  readonly CYAN=$'\033[0;36m'
  readonly WHITE=$'\033[1;37m'
  readonly GRAY=$'\033[0;90m'
  readonly LIGHT_GRAY=$'\033[0;37m'
  readonly NC=$'\033[0m'
  readonly ICON_CHECK="✓"
  readonly ICON_CROSS="✗"
  readonly ICON_ARROW="→"
  readonly ICON_WARN="⚠"
  readonly ICON_INFO="ℹ"
else
  readonly RED=""
  readonly GREEN=""
  readonly YELLOW=""
  readonly BLUE=""
  readonly MAGENTA=""
  readonly CYAN=""
  readonly WHITE=""
  readonly GRAY=""
  readonly LIGHT_GRAY=""
  readonly NC=""
  readonly ICON_CHECK="[OK]"
  readonly ICON_CROSS="[ERROR]"
  readonly ICON_ARROW=">"
  readonly ICON_WARN="[WARN]"
  readonly ICON_INFO="[INFO]"
fi

# These are retained as public constants; they are not rendered in logs.
# shellcheck disable=SC2034
readonly ICON_KEY="[KEY]"
# shellcheck disable=SC2034
readonly ICON_LOCK="[LOCK]"
# shellcheck disable=SC2034
readonly ICON_GIT="[GIT]"
# shellcheck disable=SC2034
readonly ICON_GITHUB="[GITHUB]"
# shellcheck disable=SC2034
readonly ICON_GEAR="[GEAR]"
# shellcheck disable=SC2034
readonly ICON_ROCKET="[ROCKET]"
# shellcheck disable=SC2034
readonly ICON_PACKAGE="[PACKAGE]"
# RavnVM workflow icons retained as reusable public constants.
# shellcheck disable=SC2034
readonly ICON_SNAPSHOT="📸"
# shellcheck disable=SC2034
readonly ICON_BUILD="🔨"
# shellcheck disable=SC2034
readonly ICON_VM="🖥️"
# shellcheck disable=SC2034
readonly ICON_INSTRUCTIONS="📋"
# shellcheck disable=SC2034
readonly ICON_WAITING="⏳"
# shellcheck disable=SC2034
readonly ICON_CLEANING="🧹"

# Nerd Font catalog from Scripts/icons.lua. Keep semantic aliases above stable
# for existing consumers; use this namespaced catalog for new interfaces.
declare -Ar RAVN_ICON=(
       [diagnostics_error]=" "
       [diagnostics_hint]="󰠠 "
       [diagnostics_information]=" "
       [diagnostics_question]=" "
       [diagnostics_warning]=" "
       [documents_file]=" "
       [documents_folder]=" "
       [documents_open_folder]=" "
       [documents_symlink]=" "
       [git_branch]=" "
       [git_diff]=" "
       [git_github]=" "
       [git_remove]=" "
       [git_repository]=" "
       [git_tag]=" "
       [kind_class]=" "
       [kind_function]="󰊕 "
       [kind_method]=" "
       [kind_module]=" "
       [kind_variable]=" "
       [type_array]=" "
       [type_boolean]="⏻ "
       [type_number]=" "
       [type_object]=" "
       [type_string]=" "
       [ui_arrow]=" "
       [ui_arrow_left]=" "
       [ui_arrow_right]=" "
       [ui_bookmark]=" "
       [ui_bug]=" "
       [ui_check]=" "
       [ui_close]=" "
       [ui_code]=" "
       [ui_command]=" "
       [ui_dashboard]=" "
       [ui_database]=" "
       [ui_download]=" "
       [ui_eye]=" "
       [ui_flag]=" "
       [ui_gear]=" "
       [ui_github]=" "
       [ui_history]=" "
       [ui_list]=" "
       [ui_lock]=" "
       [ui_package]=" "
       [ui_play]=" "
       [ui_power]=" "
       [ui_project]=" "
       [ui_question]=" "
       [ui_reload]=" "
       [ui_rocket]=" "
       [ui_save]="󰆓 "
       [ui_search]=" "
       [ui_storage]="󰋊 "
       [ui_table]=" "
       [ui_terminal]=" "
       [ui_test]=" "
       [ui_time]=" "
       [ui_trash]=" "
       [ui_wifi]=" "
)

# shellcheck disable=SC2034
readonly ICON_DIAGNOSTIC_ERROR="${RAVN_ICON[diagnostics_error]}"
# shellcheck disable=SC2034
readonly ICON_DIAGNOSTIC_INFO="${RAVN_ICON[diagnostics_information]}"
# shellcheck disable=SC2034
readonly ICON_DIAGNOSTIC_WARNING="${RAVN_ICON[diagnostics_warning]}"
# shellcheck disable=SC2034
readonly ICON_GIT_BRANCH="${RAVN_ICON[git_branch]}"
# shellcheck disable=SC2034
readonly ICON_UI_GEAR="${RAVN_ICON[ui_gear]}"
# shellcheck disable=SC2034
readonly ICON_UI_COMMAND="${RAVN_ICON[ui_command]}"
# shellcheck disable=SC2034
readonly ICON_UI_DATABASE="${RAVN_ICON[ui_database]}"
# shellcheck disable=SC2034
readonly ICON_UI_DOWNLOAD="${RAVN_ICON[ui_download]}"
# shellcheck disable=SC2034
readonly ICON_UI_PLAY="${RAVN_ICON[ui_play]}"
# shellcheck disable=SC2034
readonly ICON_UI_ROCKET="${RAVN_ICON[ui_rocket]}"
# shellcheck disable=SC2034
readonly ICON_UI_SAVE="${RAVN_ICON[ui_save]}"
# shellcheck disable=SC2034
readonly ICON_UI_LIST="${RAVN_ICON[ui_list]}"
# shellcheck disable=SC2034
readonly ICON_UI_PACKAGE="${RAVN_ICON[ui_package]}"
# shellcheck disable=SC2034
readonly ICON_UI_CLOSE="${RAVN_ICON[ui_close]}"
# shellcheck disable=SC2034
readonly ICON_UI_ARROW_LEFT="${RAVN_ICON[ui_arrow_left]}"
# shellcheck disable=SC2034
readonly ICON_UI_ARROW="${RAVN_ICON[ui_arrow]}"
# shellcheck disable=SC2034
readonly ICON_UI_BOOKMARK="${RAVN_ICON[ui_bookmark]}"
# shellcheck disable=SC2034
readonly ICON_UI_STORAGE="${RAVN_ICON[ui_storage]}"
# shellcheck disable=SC2034
readonly ICON_UI_TERMINAL="${RAVN_ICON[ui_terminal]}"
# shellcheck disable=SC2034
readonly ICON_UI_TEST="${RAVN_ICON[ui_test]}"
# shellcheck disable=SC2034
readonly ICON_UI_TRASH="${RAVN_ICON[ui_trash]}"

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Global Variables                                                             │
# └──────────────────────────────────────────────────────────────────────────────┘

scrDir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
cloneDir="${CLONE_DIR:-$(dirname "$scrDir")}"
confDir="${XDG_CONFIG_HOME:-$HOME/.config}"
cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}/ravn"
aurList=("yay" "paru")
shlList=("zsh" "fish")
pacmanCmd="${cloneDir}/Configs/.local/lib/hyde/pm.sh"

export cloneDir
export confDir
export cacheDir
export aurList
export shlList

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Package Management                                                           │
# └──────────────────────────────────────────────────────────────────────────────┘

pkg_installed() {
  local package_name="$1"

  pacman -Q "$package_name" &> /dev/null
}

chk_list() {
  local variable_name="$1"
  local package_name=""
  local packages=("${@:2}")

  for package_name in "${packages[@]}"; do
    if pkg_installed "$package_name"; then
      printf -v "$variable_name" '%s' "$package_name"
      # shellcheck disable=SC2163 # Dynamic variable name is part of the public contract.
      export "$variable_name"
      return 0
    fi
  done

  return 1
}

pkg_available() {
  local package_name="$1"

  "$pacmanCmd" query "$package_name" &> /dev/null
}

aur_available() {
  local package_name="$1"

  "$pacmanCmd" info "$package_name" &> /dev/null
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Hardware Detection                                                           │
# └──────────────────────────────────────────────────────────────────────────────┘

nvidia_detect() {
  local gpu_name=""
  local gpu_code=""
  local index=""

  readarray -t dGPU < <(lspci -k | grep -E "(VGA|3D)" | awk -F ': ' '{print $NF}')

  case "${1:-}" in
    --verbose)
      for index in "${!dGPU[@]}"; do
        echo -e "${GREEN}[gpu${index}]${NC} detected :: ${dGPU[$index]}"
      done
      return 0
      ;;
    --drivers)
      for gpu_name in "${dGPU[@]}"; do
        gpu_code="${gpu_name%% *}"
        awk -F '|' -v nvc="$gpu_code" 'substr(nvc, 1, length($3)) == $3 {split(FILENAME, driver, "/"); print driver[length(driver)], "\nnvidia-utils"}' "${scrDir}"/nvidia-db/nvidia*dkms
      done
      return 0
      ;;
  esac

  grep -iq nvidia <<< "${dGPU[*]}"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Interactive Utilities                                                        │
# └──────────────────────────────────────────────────────────────────────────────┘

prompt_timer() {
  local message="$2"
  local prompt_input="/dev/stdin"
  local remaining_seconds="$1"

  unset PROMPT_INPUT

  if [[ -t 0 && -r /dev/tty ]]; then
    prompt_input="/dev/tty"
  fi

  while ((remaining_seconds >= 0)); do
    echo -ne "\r :: ${message} (${remaining_seconds}s) : "
    if IFS= read -r -t 1 -n 1 PROMPT_INPUT < "$prompt_input"; then
      break
    fi
    ((remaining_seconds--))
  done

  export PROMPT_INPUT
  echo ""
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Helper Functions                                                             │
# └──────────────────────────────────────────────────────────────────────────────┘

# cleanup() - Generic cleanup function template
# Each script should override this function to define its own cleanup logic.
# The trap is set in each individual script because it depends on script-specific resources.
cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # Override this function in your script to add custom cleanup logic
  # Example:
  #   if [[ -f /tmp/my_temp_file ]]; then
  #     rm -f /tmp/my_temp_file
  #   fi
}

print_header() {
  echo ""
  echo -e "${CYAN}╭────────────────────────────────────────────────────────────╮${NC}"
  echo -e "${CYAN}│${NC}  ${WHITE}$1${NC}"
  echo -e "${CYAN}╰────────────────────────────────────────────────────────────╯${NC}"
}

print_section() {
  echo ""
  echo -e "${MAGENTA}  $1${NC}"
  echo -e "${GRAY}  ──────────────────────────────────────────────────────────${NC}"
}

print_step() {
  echo -e "  ${GRAY}${ICON_ARROW}${NC} $1"
}

print_success() {
  echo -e "  ${GREEN}${ICON_CHECK}${NC} $1"
}

print_error() {
  echo -e "  ${RED}${ICON_CROSS}${NC} $1"
}

print_warn() {
  echo -e "  ${YELLOW}${ICON_WARN}${NC} $1"
}

print_info() {
  echo -e "  ${BLUE}${ICON_INFO}${NC} $1"
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Console Output & Logging                                                     │
# └──────────────────────────────────────────────────────────────────────────────┘

info() {
  print_info "$*"
}

success() {
  print_success "$*"
}

warn_msg() {
  print_warn "$*" >&2
}

error_msg() {
  print_error "$*" >&2
}

step() {
  print_step "$*"
}

print_ravn_banner() {
  local subtitle="${1:-RaVN Task Runner}"

  echo -e "${CYAN}"
  cat << 'BANNER_EOF'
  ╭────────────────────────────────────────────────────╮
  │                                                    │
  │  ██████╗  █████╗ ██╗   ██╗███╗   ██╗               │
  │  ██╔══██╗██╔══██╗██║   ██║████╗  ██║               │
  │  ██████╔╝███████║██║   ██║██╔██╗ ██║               │
  │  ██╔══██╗██╔══██║╚██╗ ██╔╝██║╚██╗██║               │
  │  ██║  ██║██║  ██║ ╚████╔╝ ██║ ╚████║               │
  │  ╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝  ╚═══╝               │
  │                                                    │
BANNER_EOF
  printf '  │       %-44s│\n' "$subtitle"
  printf '  │       %b%-19s%b %b%-12s%b          │\n' \
    "$GRAY" "by Roberto Flores" "$CYAN" "$WHITE" "@robert-flo" "$CYAN"
  cat << 'BANNER_EOF'
  │                                                    │
  ╰────────────────────────────────────────────────────╯
BANNER_EOF
  echo -e "${NC}"
}

print_log() {
  local color=""
  local executable="${0##*/}"
  local log_file="${cacheDir}/logs/${RAVN_LOG:-}/${executable}.log"
  local message=""
  local section="${log_section:-}"

  if [[ -n $section ]]; then
    message+="${GREEN}[${section}] ${NC}"
  fi

  while (($#)); do
    case "$1" in
      -r | +r)
        message+="${RED}${2}${NC}"
        shift 2
        ;;
      -g | +g)
        message+="${GREEN}${2}${NC}"
        shift 2
        ;;
      -y | +y)
        message+="${YELLOW}${2}${NC}"
        shift 2
        ;;
      -b | +b)
        message+="${BLUE}${2}${NC}"
        shift 2
        ;;
      -m | +m)
        message+="${MAGENTA}${2}${NC}"
        shift 2
        ;;
      -c | +c)
        message+="${CYAN}${2}${NC}"
        shift 2
        ;;
      -wt | +w)
        message+="${WHITE}${2}${NC}"
        shift 2
        ;;
      -n | +n)
        message+="\033[0;96m${2}${NC}"
        shift 2
        ;;
      -stat)
        message+="\033[30;46m ${2} ${NC} :: "
        shift 2
        ;;
      -crit)
        message+="\033[97;41m ${2} ${NC} :: "
        shift 2
        ;;
      -warn)
        message+="WARNING :: \033[30;43m ${2} ${NC} :: "
        shift 2
        ;;
      +)
        printf -v color '\033[38;5;%sm' "$2"
        message+="${color}${3}${NC}"
        shift 3
        ;;
      -sec)
        message+="${GREEN}[${2}] ${NC}"
        shift 2
        ;;
      -err)
        message+="ERROR :: \033[4;31m${2} ${NC}"
        shift 2
        ;;
      *)
        message+="$1"
        shift
        ;;
    esac
  done

  message+="\n"
  mkdir -p "$(dirname "$log_file")"

  if [[ -n ${RAVN_LOG:-} ]]; then
    printf '%b' "$message" | tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$log_file")
  else
    printf '%b' "$message"
  fi
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Execution Helpers                                                            │
# └──────────────────────────────────────────────────────────────────────────────┘

spin() {
  local character=""
  local exit_code=0
  local index=0
  local message="${2:-Working...}"
  local pid="$1"
  local spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

  if [[ ! -t 1 ]]; then
    wait "$pid" || exit_code=$?
    return "$exit_code"
  fi

  tput civis 2> /dev/null || true

  while kill -0 "$pid" 2> /dev/null; do
    character="${spinner:$index:1}"
    printf "\r  ${CYAN}%s${NC} %s" "$character" "$message"
    index=$(((index + 1) % ${#spinner}))
    sleep 0.08
  done

  tput cnorm 2> /dev/null || true
  wait "$pid" || exit_code=$?

  if ((exit_code == 0)); then
    printf "\r  ${GREEN}${ICON_CHECK}${NC} %s\n" "$message"
  else
    printf "\r  ${RED}${ICON_CROSS}${NC} %s\n" "$message"
  fi

  return "$exit_code"
}

run_with_status() {
  local message="$1"
  shift

  if ((${flg_DryRun:-0} == 1)); then
    echo -e "  ${YELLOW}⊘${NC} ${message} (dry-run)"
    return 0
  fi

  if [[ ${1:-} == "sudo" ]]; then
    sudo -v 2> /dev/null || true
  fi

  "$@" &> /dev/null &
  spin "$!" "$message"
}

retry() {
  local max_tries="$1"
  local pause_seconds=2
  local remaining_tries="$1"
  shift

  if "$@"; then
    return 0
  fi

  remaining_tries=$((remaining_tries - 1))
  while ((remaining_tries > 0)); do
    warn_msg "Reintentando en ${pause_seconds}s (${remaining_tries} intentos restantes): $*"
    sleep "$pause_seconds"
    pause_seconds=$((pause_seconds * 2))

    if "$@"; then
      return 0
    fi

    remaining_tries=$((remaining_tries - 1))
  done

  error_msg "Falló después de ${max_tries} intentos: $*"
  return 1
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Download Helpers                                                             │
# └──────────────────────────────────────────────────────────────────────────────┘

download_file() {
  local output="${2:-}"
  local url="$1"

  if command_exists curl; then
    if [[ -n $output ]]; then
      curl -fsSL -o "$output" "$url"
    else
      curl -fsSL "$url"
    fi
  elif command_exists wget; then
    if [[ -n $output ]]; then
      wget -q -O "$output" "$url"
    else
      wget -q -O - "$url"
    fi
  else
    error_msg "Se requiere curl o wget, pero ninguno está instalado"
    return 1
  fi
}

download_with_spinner() {
  local message="${3:-Descargando...}"
  local output="$2"
  local url="$1"

  download_file "$url" "$output" &> /dev/null &
  spin "$!" "$message"
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Repository Helpers                                                           │
# └──────────────────────────────────────────────────────────────────────────────┘

clone_or_update_repo() {
  local destination="$3"
  local name="$1"
  local prefer_ssh="${5:-}"
  local ref="${4:-master}"
  local remote_url=""
  local repository="$2"

  remote_url="https://github.com/${repository}.git"

  if [[ $prefer_ssh == "ssh" ]]; then
    if { [[ -f $HOME/.ssh/id_ed25519 ]] || [[ -f $HOME/.ssh/id_rsa ]]; } && ssh -T -o ConnectTimeout=3 -o BatchMode=yes git@github.com 2>&1 | grep -q "successfully authenticated"; then
      remote_url="git@github.com:${repository}.git"
      info "Llave SSH autorizada detectada. Usando protocolo SSH para ${name}."
    elif [[ -f $HOME/.ssh/id_ed25519 || -f $HOME/.ssh/id_rsa ]]; then
      warn_msg "Llave SSH detectada pero no autorizada en GitHub. Usando protocolo HTTPS para ${name}."
    fi
  fi

  if ((${flg_DryRun:-0} == 1)); then
    echo -e "  ${YELLOW}⊘${NC} Clonar/actualizar ${name} (dry-run)"
    return 0
  fi

  if [[ -d $destination/.git ]]; then
    info "Actualizando ${name} existente..."
    git -C "$destination" remote set-url origin "$remote_url" &> /dev/null || true
    if retry 3 git -C "$destination" fetch origin "$ref" &> /dev/null &&
      git -C "$destination" checkout "$ref" &> /dev/null &&
      git -C "$destination" reset --hard "origin/${ref}" &> /dev/null; then
      success "${name} sincronizado en la rama ${ref}."
    else
      error_msg "No se pudo sincronizar ${name}."
      return 1
    fi
  else
    info "Clonando ${name} desde: ${remote_url}"
    if retry 3 git clone "$remote_url" "$destination" &> /dev/null; then
      git -C "$destination" fetch origin "$ref" &> /dev/null &&
        git -C "$destination" checkout "$ref" &> /dev/null

      if [[ $prefer_ssh == "ssh" && $remote_url == git@* ]]; then
        git -C "$destination" remote set-url origin "$remote_url"
      fi
      success "${name} sincronizado en la rama ${ref}."
    else
      error_msg "No se pudo clonar ${name}."
      return 1
    fi
  fi
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Installation Statistics                                                      │
# └──────────────────────────────────────────────────────────────────────────────┘

_install_ok=0
_install_fail=0
_install_skip=0
_install_ok_list=()
_install_fail_list=()
_install_skip_list=()

count_ok() {
  _install_ok=$((_install_ok + 1))
  if [[ -n ${1:-} ]]; then
    _install_ok_list+=("$1")
  fi
}

count_fail() {
  _install_fail=$((_install_fail + 1))
  if [[ -n ${1:-} ]]; then
    _install_fail_list+=("$1")
  fi
}

count_skip() {
  _install_skip=$((_install_skip + 1))
  if [[ -n ${1:-} ]]; then
    _install_skip_list+=("$1")
  fi
}

print_item_list() {
  local indent="      "
  local item=""
  local items=("${@:2}")
  local prefix="$1"
  local total_items=${#items[@]}
  local list=""
  local index=""

  ((total_items > 0)) || return 0

  if ((total_items <= 5)); then
    for item in "${items[@]}"; do
      [[ -n $list ]] && list+=", "
      list+="$item"
    done
    printf "%b %s\n" "$prefix" "$list"
    return 0
  fi

  printf "%b\n" "$prefix"
  printf "%s%s" "$indent" "${items[0]}"
  for ((index = 1; index < total_items; index++)); do
    if ((index % 4 == 0)); then
      printf ",\n%s%s" "$indent" "${items[index]}"
    else
      printf ", %s" "${items[index]}"
    fi
  done
  printf "\n"
}

print_summary() {
  local border=""
  local label="${1:-Installation}"
  local total=$((_install_ok + _install_fail + _install_skip))
  local title="RaVN ${label} Summary"
  local w=39
  local title_len=${#title}
  local pad_left=0
  local pad_right=0

  # Si el título excede el ancho de la caja, se trunca para no romper el layout
  # (evita padding negativo y desalineación de las filas de estadísticas).
  if ((title_len > w - 2)); then
    title="${title:0:$((w - 5))}..."
    title_len=${#title}
  fi

  pad_left=$(((w - title_len) / 2))
  pad_right=$((w - title_len - pad_left))

  border=$(printf '─%.0s' $(seq 1 "$w"))
  echo ""
  echo -e "  ${GRAY}┌${border}┐${NC}"
  printf "  ${GRAY}│${NC}${WHITE}%*s%s%*s${NC}${GRAY}│${NC}\n" "$pad_left" "" "$title" "$pad_right" ""
  echo -e "  ${GRAY}├${border}┤${NC}"
  printf "  ${GRAY}│${NC}  ${GREEN}${ICON_CHECK}${NC} Exitosos:%25s ${GRAY}│${NC}\n" "$_install_ok"
  printf "  ${GRAY}│${NC}  ${RED}${ICON_CROSS}${NC} Fallidos:%25s ${GRAY}│${NC}\n" "$_install_fail"
  printf "  ${GRAY}│${NC}  ${YELLOW}⊘${NC} Omitidos:%25s ${GRAY}│${NC}\n" "$_install_skip"
  echo -e "  ${GRAY}├${border}┤${NC}"
  printf "  ${GRAY}│${NC}  Total:${WHITE}%30s${NC} ${GRAY}│${NC}\n" "$total"
  echo -e "  ${GRAY}└${border}┘${NC}"
  echo ""

  if ((total > 0)); then
    echo -e "  ${WHITE}Detalles:${NC}"
    if ((${#_install_ok_list[@]} > 0)); then
      print_item_list "    ${GREEN}${ICON_CHECK}${NC} ${WHITE}Exitosos (${#_install_ok_list[@]}):${NC}" "${_install_ok_list[@]}"
    fi
    if ((${#_install_fail_list[@]} > 0)); then
      print_item_list "    ${RED}${ICON_CROSS}${NC} ${WHITE}Fallidos (${#_install_fail_list[@]}):${NC}" "${_install_fail_list[@]}"
    fi
    if ((${#_install_skip_list[@]} > 0)); then
      print_item_list "    ${YELLOW}⊘${NC} ${WHITE}Omitidos (${#_install_skip_list[@]}):${NC}" "${_install_skip_list[@]}"
    fi
    echo ""
  fi
}
