#!/usr/bin/env bash

set -Eeuo pipefail

readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ravnvm"
readonly BASE_IMAGE="$CACHE_DIR/archbase.qcow2"
readonly SNAPSHOTS_DIR="$CACHE_DIR/snapshots"
readonly RAVN_REPO="${RAVN_REPO:-https://github.com/robert-flo/RaVN.git}"
readonly ARCH_IMAGE_URL="${RAVNVM_ARCH_IMAGE_URL:-https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-basic.qcow2}"
readonly SSH_PORT="${RAVNVM_SSH_PORT:-2222}"
readonly DEFAULT_MEMORY="4G"
readonly DEFAULT_CPUS="2"

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m'

readonly -a REQUIRED_COMMANDS=(qemu-system-x86_64 qemu-img curl git ssh ssh-keyscan scp sha256sum)
readonly -a ARCH_PACKAGES=(qemu-desktop curl git openssh)

ACTIVE_QEMU_PID=""
TEMPORARY_PATHS=()

print_error() {
  printf "${RED}Error:${NC} %s\n" "$*" >&2
}

print_warning() {
  printf "${YELLOW}Warning:${NC} %s\n" "$*" >&2
}

print_success() {
  printf "${GREEN}%s${NC}\n" "$*"
}

cleanup_runtime() {
  local temporary_path=""

  if [[ -n $ACTIVE_QEMU_PID ]] && kill -0 "$ACTIVE_QEMU_PID" 2> /dev/null; then
    kill "$ACTIVE_QEMU_PID" 2> /dev/null || true
    wait "$ACTIVE_QEMU_PID" 2> /dev/null || true
  fi
  for temporary_path in "${TEMPORARY_PATHS[@]}"; do
    rm -rf -- "$temporary_path"
  done
  rm -f -- "$BASE_IMAGE.part"
}

handle_interrupt() {
  print_warning "RavnVM interrupted; temporary state was removed and the cached base was preserved"
  exit 130
}

register_temporary_path() {
  TEMPORARY_PATHS+=("$1")
}

trap handle_interrupt INT TERM
trap cleanup_runtime EXIT

print_usage() {
  cat << 'USAGE'
RavnVM - isolated VM tool for RaVN contributors

Usage: ravnvm [OPTIONS] [BRANCH/COMMIT]

Arguments:
  BRANCH/COMMIT            Git branch or commit hash (default: master)

Options:
  --persist                Retain changes in the revision snapshot
  --list                   List available revision snapshots
  --clean                  Remove snapshots and temporary VM data
  --storage                Show cache and filesystem storage usage
  --install-deps           Install required packages on Arch Linux
  --check-deps             Check host dependencies
  --ssh                    Connect to the running VM
  --help                   Show this help

Environment variables:
  VM_MEMORY=4G             VM memory (default: 4G)
  VM_CPUS=2                VM CPU count (default: 2)
  VM_EXTRA_ARGS="args"      Additional QEMU arguments
  VM_QEMU_OVERRIDE="cmd"    Replacement QEMU command; $VM_DISK is substituted
  RAVN_REPO="url"           RaVN Git repository cloned inside the VM
USAGE
}

detect_os() {
  local id=""
  local id_like=""

  if [[ -r /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    id="${ID:-}"
    id_like="${ID_LIKE:-}"
  fi

  if [[ $id == nixos ]] || command -v nixos-version > /dev/null 2>&1; then
    printf 'nixos\n'
  elif [[ $id == arch || $id_like == *arch* ]] || command -v pacman > /dev/null 2>&1; then
    printf 'arch\n'
  else
    printf 'unknown\n'
  fi
}

missing_commands() {
  local command_name=""

  for command_name in "${REQUIRED_COMMANDS[@]}"; do
    command -v "$command_name" > /dev/null 2>&1 || printf '%s\n' "$command_name"
  done
}

check_dependencies() {
  local os=""
  local missing=""

  os=$(detect_os)
  missing=$(missing_commands)
  if [[ -n $missing ]]; then
    print_error "Missing required commands: $(tr '\n' ' ' <<< "$missing" | sed 's/ $//')"
    case "$os" in
      arch)
        printf 'Install them with: ravnvm --install-deps\n' >&2
        ;;
      nixos)
        printf 'Use a Nix shell containing qemu, curl, git, and openssh.\n' >&2
        ;;
      *)
        printf 'Install QEMU, curl, Git, and OpenSSH with your package manager.\n' >&2
        ;;
    esac
    return 1
  fi

  if [[ ! -r /dev/kvm ]]; then
    print_warning "KVM is unavailable; QEMU will run without hardware acceleration"
  fi

  return 0
}

check_dependencies_only() {
  local os=""

  os=$(detect_os)
  printf 'Detected OS: %s\n' "$os"
  check_dependencies
  print_success "All required RavnVM commands are available"
}

install_arch_dependencies() {
  if [[ $(detect_os) != arch ]]; then
    print_error "--install-deps is supported only on Arch Linux"
    return 1
  fi

  sudo pacman -Sy --needed "${ARCH_PACKAGES[@]}"
  print_success "RavnVM dependencies installed"
  if getent group kvm > /dev/null 2>&1 && [[ ! -r /dev/kvm ]]; then
    print_warning "Add your user to the kvm group, then log in again, to enable acceleration"
  fi
}

ensure_cache() {
  mkdir -p "$CACHE_DIR" "$SNAPSHOTS_DIR"
}

snapshot_id_for() {
  local revision="$1"
  local slug="${revision//[^a-zA-Z0-9._-]/_}"
  local digest=""

  slug="${slug:0:64}"
  digest=$(printf '%s' "$revision" | sha256sum | cut -c 1-12)
  printf '%s-%s\n' "$slug" "$digest"
}

snapshot_path_for() {
  local revision="$1"
  printf '%s/ravn-%s.qcow2\n' "$SNAPSHOTS_DIR" "$(snapshot_id_for "$revision")"
}

list_snapshots() {
  local snapshots=""

  ensure_cache
  printf 'Available RaVN snapshots:\n'
  snapshots=$(find "$SNAPSHOTS_DIR" -type f -name 'ravn-*.qcow2' -printf '%f\n' |
    sed -e 's/^ravn-//' -e 's/\.qcow2$//' | sort)
  if [[ -n $snapshots ]]; then
    printf '%s\n' "$snapshots"
  else
    printf 'No snapshots found\n'
  fi
}

clean_cache() {
  if ! ensure_cache; then
    print_error "Unable to prepare the RavnVM cache"
    return 1
  fi
  printf 'Cleaning RavnVM cache while preserving the base image...\n'
  if ! find "$CACHE_DIR" -mindepth 1 -maxdepth 1 ! -name 'archbase.qcow2' -exec rm -rf -- {} +; then
    print_error "Unable to clean RavnVM cache"
    return 1
  fi
  if ! mkdir -p "$SNAPSHOTS_DIR"; then
    print_error "Unable to recreate the snapshots directory"
    return 1
  fi
  if [[ -f $BASE_IMAGE ]]; then
    print_success "Cache cleaned; base image preserved"
  else
    print_success "Cache cleaned"
  fi
}

download_base_image() {
  ensure_cache
  if [[ -f $BASE_IMAGE ]]; then
    return 0
  fi

  printf 'Downloading the Arch Linux base image...\n'
  curl --fail --location "$ARCH_IMAGE_URL" --output "$BASE_IMAGE.part"
  mv "$BASE_IMAGE.part" "$BASE_IMAGE"
  print_success "Base image downloaded"
}

qemu_command() {
  local vm_disk="$1"
  local memory="$2"
  local cpus="$3"
  local execution_mode="${4:-foreground}"
  local -a args=(
    -m "$memory"
    -smp "$cpus"
    -drive "file=$vm_disk,format=qcow2,if=virtio"
    -device "virtio-vga-gl"
    -display "gtk,gl=on,grab-on-hover=on"
    -boot "menu=on"
  )
  local -a extra_args=()

  if [[ -n ${VM_QEMU_OVERRIDE:-} ]]; then
    local override="${VM_QEMU_OVERRIDE//\$VM_DISK/$vm_disk}"
    printf 'Using the configured QEMU override...\n'
    if [[ $execution_mode == background ]]; then
      bash -c "$override" &
      ACTIVE_QEMU_PID=$!
      return 0
    fi
    bash -c "$override"
    return
  fi

  if [[ -r /dev/kvm ]]; then
    args+=(-enable-kvm -cpu host)
  else
    args+=(-cpu qemu64)
  fi

  args+=(-device "virtio-net,netdev=net0" -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22")

  if [[ -n ${VM_EXTRA_ARGS:-} ]]; then
    read -r -a extra_args <<< "$VM_EXTRA_ARGS"
    args+=("${extra_args[@]}")
  fi

  if [[ $execution_mode == background ]]; then
    qemu-system-x86_64 "${args[@]}" 2> "$CACHE_DIR/qemu.log" &
    ACTIVE_QEMU_PID=$!
    return 0
  fi

  if ! qemu-system-x86_64 "${args[@]}" 2> "$CACHE_DIR/qemu.log"; then
    print_error "QEMU failed; see $CACHE_DIR/qemu.log"
    return 1
  fi
}

write_guest_setup() {
  local destination="$1"

  cat > "$destination" << 'GUEST_SETUP'
#!/usr/bin/env bash
set -Eeuo pipefail

repo_url="$1"
revision="$2"
checkout_dir="$HOME/RaVN"

if [[ -d "$checkout_dir/.git" ]]; then
  git -C "$checkout_dir" remote set-url origin "$repo_url"
  git -C "$checkout_dir" fetch --prune origin
else
  git clone "$repo_url" "$checkout_dir"
fi

git -C "$checkout_dir" fetch origin "$revision" || true
if git -C "$checkout_dir" rev-parse --verify --quiet "origin/$revision" > /dev/null; then
  git -C "$checkout_dir" checkout --force -B "$revision" "origin/$revision"
else
  git -C "$checkout_dir" checkout --force "$revision"
fi

cd "$checkout_dir/Scripts"
./install.sh
GUEST_SETUP
  chmod +x "$destination"
}

copy_setup_when_ready() {
  local qemu_pid="$1"
  local setup_script="$2"
  local attempt=0
  local -a ssh_options=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

  for ((attempt = 1; attempt <= 120; attempt++)); do
    if ! kill -0 "$qemu_pid" 2> /dev/null; then
      print_error "The setup VM stopped before SSH became available"
      return 1
    fi
    if ssh-keyscan -p "$SSH_PORT" 127.0.0.1 2> /dev/null | grep -q 'ssh-'; then
      scp -P "$SSH_PORT" "${ssh_options[@]}" "$setup_script" arch@127.0.0.1:/home/arch/setup.sh
      return 0
    fi
    sleep 1
  done

  print_error "Timed out waiting for the setup VM SSH service"
  return 1
}

create_snapshot() {
  local revision="$1"
  local snapshot_path=""
  local temporary_disk=""
  local setup_script=""
  local setup_completed=""
  local qemu_pid=""

  snapshot_path=$(snapshot_path_for "$revision")
  [[ -f $snapshot_path ]] && return 0

  download_base_image
  temporary_disk=$(mktemp -p "$CACHE_DIR" 'setup.XXXXXX.qcow2')
  setup_script=$(mktemp -p "$CACHE_DIR" 'setup.XXXXXX.sh')
  register_temporary_path "$temporary_disk"
  register_temporary_path "$setup_script"
  qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMAGE" "$temporary_disk"
  write_guest_setup "$setup_script"

  printf 'Creating the RaVN snapshot for %s...\n' "$revision"
  printf 'After login, run: ./setup.sh %q %q; then sudo poweroff\n' "$RAVN_REPO" "$revision"
  qemu_command "$temporary_disk" "${VM_MEMORY:-$DEFAULT_MEMORY}" "${VM_CPUS:-$DEFAULT_CPUS}" background
  qemu_pid="$ACTIVE_QEMU_PID"

  if ! copy_setup_when_ready "$qemu_pid" "$setup_script"; then
    kill "$qemu_pid" 2> /dev/null || true
    wait "$qemu_pid" 2> /dev/null || true
    ACTIVE_QEMU_PID=""
    return 1
  fi

  if ! wait "$qemu_pid"; then
    ACTIVE_QEMU_PID=""
    print_error "The setup VM exited with an error; no snapshot was cached"
    return 1
  fi
  ACTIVE_QEMU_PID=""

  if ! read -r -p "Did RaVN setup complete successfully inside the VM? [y/N] " setup_completed ||
    [[ ! $setup_completed =~ ^[Yy]$ ]]; then
    print_error "Setup was not confirmed; no revision snapshot was cached"
    return 1
  fi

  if ! qemu-img convert -O qcow2 "$temporary_disk" "$snapshot_path"; then
    rm -f "$snapshot_path"
    print_error "Unable to create the revision snapshot"
    return 1
  fi
  rm -f "$temporary_disk" "$setup_script"
  TEMPORARY_PATHS=()
  print_success "Snapshot created for $revision"
}

run_vm() {
  local revision="$1"
  local persistent="$2"
  local snapshot_path=""
  local vm_disk=""
  local status=0

  snapshot_path=$(snapshot_path_for "$revision")
  create_snapshot "$revision"

  if [[ $persistent == true ]]; then
    printf 'Running in persistent mode; changes will be retained.\n'
    vm_disk="$snapshot_path"
  else
    printf 'Running in non-persistent mode; changes will be discarded.\n'
    vm_disk=$(mktemp -p "$CACHE_DIR" 'overlay.XXXXXX.qcow2')
    register_temporary_path "$vm_disk"
    qemu-img create -f qcow2 -F qcow2 -b "$snapshot_path" "$vm_disk"
  fi

  printf 'Starting RaVN VM (branch/commit: %s)...\n' "$revision"
  printf 'Login: arch / arch; SSH: ssh arch@127.0.0.1 -p %s\n' "$SSH_PORT"
  qemu_command "$vm_disk" "${VM_MEMORY:-$DEFAULT_MEMORY}" "${VM_CPUS:-$DEFAULT_CPUS}" || status=$?

  if [[ $persistent != true ]]; then
    rm -f "$vm_disk"
    TEMPORARY_PATHS=()
  fi
  return "$status"
}

connect_ssh() {
  ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null arch@127.0.0.1
}

run_revision() {
  local revision="$1"
  local persistent="$2"

  if ((EUID == 0)); then
    print_error "Do not run RavnVM as root"
    return 1
  fi
  check_dependencies
  run_vm "$revision" "$persistent"
}

print_section() {
  printf '\n%s\n' "$1"
  printf '%s\n' '────────────────────────────────────────────────────────────'
}

press_enter_to_continue() {
  read -r -p 'Press Enter to continue...' _ || true
}

print_banner() {
  cat << 'BANNER'

  RavnVM — QEMU/KVM Development Environment
BANNER
}

format_bytes() {
  local bytes="${1:-0}"

  awk -v bytes="$bytes" 'BEGIN {
    split("B KiB MiB GiB TiB", units)
    unit = 1
    while (bytes >= 1024 && unit < 5) {
      bytes /= 1024
      unit++
    }
    printf "%.2f %s", bytes, units[unit]
  }'
}

show_storage_status() {
  local cache_bytes=0
  local filesystem_total=0
  local filesystem_used=0
  local filesystem_available=0
  local filesystem_percent=0
  local storage_label="Available"

  ensure_cache
  cache_bytes=$(du -s -B1 "$CACHE_DIR" 2> /dev/null | awk '{print $1}' || printf '0\n')
  read -r filesystem_total filesystem_used filesystem_available filesystem_percent < <(
    df -P -B1 "$CACHE_DIR" 2> /dev/null | awk 'NR == 2 {
      gsub("%", "", $5)
      print $2, $3, $4, $5
    }'
  ) || true

  if ((filesystem_percent >= 90)); then
    storage_label="Critical"
  elif ((filesystem_percent >= 80)); then
    storage_label="High usage"
  fi

  print_section "Storage — $storage_label"
  printf 'VM cache: %s\n' "$(format_bytes "$cache_bytes")"
  printf 'Disk: %s used / %s (%s%%)\n' \
    "$(format_bytes "$filesystem_used")" \
    "$(format_bytes "$filesystem_total")" \
    "$filesystem_percent"
  printf 'Free: %s\n' "$(format_bytes "$filesystem_available")"

  if ((filesystem_percent >= 90)); then
    print_error "Storage critically low; clean old VM snapshots before continuing"
  elif ((filesystem_percent >= 80)); then
    print_warning "Storage usage is high; review VM snapshots before creating another"
  fi
}

validate_environment() {
  local command_name=""
  local validation_failed=false

  print_section "Validating Environment"
  if ! ensure_cache; then
    print_error "RavnVM cache directory is not writable"
    return 1
  fi
  if [[ ! -w $CACHE_DIR || ! -w $SNAPSHOTS_DIR ]]; then
    print_error "RavnVM cache directory is not writable"
    validation_failed=true
  else
    printf '✓ RavnVM cache directory\n'
  fi
  for command_name in "${REQUIRED_COMMANDS[@]}"; do
    if command -v "$command_name" > /dev/null 2>&1; then
      printf '✓ %s\n' "$command_name"
    else
      printf '✗ %s not found\n' "$command_name"
      validation_failed=true
    fi
  done

  if [[ -r /dev/kvm ]]; then
    printf '✓ KVM acceleration\n'
  else
    print_warning "KVM is unavailable; QEMU will run without hardware acceleration"
  fi
  show_storage_status

  [[ $validation_failed == false ]]
}

recover_environment() {
  local recovery_choice=""

  while ! validate_environment; do
    print_section "Required dependencies missing"
    printf '  %b1%b  Install dependencies\n' "$GREEN" "$NC"
    printf '  %bq%b  Exit\n\n' "$GREEN" "$NC"
    read -r -p 'Selection: ' recovery_choice || return 1

    case "$recovery_choice" in
      1)
        install_arch_dependencies || true
        ;;
      q | Q)
        return 1
        ;;
      *)
        print_error "Choose Install dependencies or Exit"
        press_enter_to_continue
        ;;
    esac
  done
}

show_menu() {
  print_section "Choose an action"
  printf '  %b1%b   Run master branch\n' "$GREEN" "$NC"
  printf '  %b2%b   Run dev branch\n' "$GREEN" "$NC"
  printf '  %b3%b   Run current branch\n' "$GREEN" "$NC"
  printf '  %b4%b   Run other branch or commit\n' "$GREEN" "$NC"
  printf '  %b5%b   Show VM storage usage\n' "$GREEN" "$NC"
  printf '  %b6%b   Clean VM cache\n' "$GREEN" "$NC"
  printf '  %b7%b   List VM snapshots\n' "$GREEN" "$NC"
  printf '  %b8%b   Configure RAM and CPU\n' "$GREEN" "$NC"
  printf '  %b9%b   Show RavnVM usage\n' "$GREEN" "$NC"
  printf '  %b10%b  Connect to VM via SSH\n' "$GREEN" "$NC"
  printf '  %bq%b   Exit\n\n' "$GREEN" "$NC"
}

select_execution_mode() {
  local -n selected_persistence="$1"
  local mode_choice=""

  selected_persistence=""
  print_section "Choose VM mode"
  printf '  %b1%b  Ephemeral\n' "$GREEN" "$NC"
  printf '  %b2%b  Persistent\n' "$GREEN" "$NC"
  printf '  %bq%b  Back\n\n' "$GREEN" "$NC"
  read -r -p 'Selection: ' mode_choice || return 1

  case "$mode_choice" in
    1)
      # shellcheck disable=SC2034 # nameref writes the caller's selected mode
      selected_persistence=false
      ;;
    2)
      # shellcheck disable=SC2034 # nameref writes the caller's selected mode
      selected_persistence=true
      ;;
    q | Q)
      return 1
      ;;
    *)
      print_error "Invalid mode option: $mode_choice"
      return 1
      ;;
  esac
}

run_menu_revision() {
  local revision="$1"
  local persistent=""

  select_execution_mode persistent || return 0
  run_revision "$revision" "$persistent" || true
  press_enter_to_continue
}

configure_session_resources() {
  local requested_memory=""
  local requested_cpus=""
  local current_memory="${VM_MEMORY:-$DEFAULT_MEMORY}"
  local current_cpus="${VM_CPUS:-$DEFAULT_CPUS}"

  print_section "Configure VM resources"
  read -r -p "RAM [$current_memory]: " requested_memory || return 1
  read -r -p "CPUs [$current_cpus]: " requested_cpus || return 1

  requested_memory="${requested_memory:-$current_memory}"
  requested_cpus="${requested_cpus:-$current_cpus}"
  if [[ ! $requested_memory =~ ^[1-9][0-9]*[KkMmGgTt]?$ ]]; then
    print_error "RAM must be a positive number with an optional K, M, G, or T suffix"
    return 1
  fi
  if [[ ! $requested_cpus =~ ^[1-9][0-9]*$ ]]; then
    print_error "CPU count must be a positive integer"
    return 1
  fi

  VM_MEMORY="$requested_memory"
  VM_CPUS="$requested_cpus"
  export VM_MEMORY VM_CPUS
  print_success "Session resources: $VM_MEMORY RAM, $VM_CPUS CPUs"
}

current_branch() {
  local branch=""

  branch=$(git branch --show-current 2> /dev/null || true)
  printf '%s\n' "${branch:-master}"
}

run_interactive_menu() {
  local choice=""
  local custom_revision=""

  print_banner
  if ! recover_environment; then
    printf 'RavnVM closed without starting a VM\n'
    return 0
  fi

  while true; do
    show_menu
    read -r -p 'Selection: ' choice || return 0
    case "$choice" in
      1)
        run_menu_revision master
        ;;
      2)
        run_menu_revision dev
        ;;
      3)
        run_menu_revision "$(current_branch)"
        ;;
      4)
        read -r -p 'Branch or commit: ' custom_revision || return 0
        if [[ -z $custom_revision ]]; then
          print_error "A branch or commit is required"
          press_enter_to_continue
        else
          run_menu_revision "$custom_revision"
        fi
        ;;
      5)
        show_storage_status
        press_enter_to_continue
        ;;
      6)
        clean_cache || true
        press_enter_to_continue
        ;;
      7)
        list_snapshots || true
        press_enter_to_continue
        ;;
      8)
        configure_session_resources || true
        press_enter_to_continue
        ;;
      9)
        print_usage
        press_enter_to_continue
        ;;
      10)
        connect_ssh || print_error "Unable to connect to the running VM"
        press_enter_to_continue
        ;;
      q | Q)
        printf 'Goodbye!\n'
        return 0
        ;;
      *)
        print_error "Invalid option: $choice"
        press_enter_to_continue
        ;;
    esac
  done
}

main() {
  local revision="master"
  local revision_was_set=false
  local persistent=false

  if (($# == 0)); then
    run_interactive_menu
    return
  fi

  while (($# > 0)); do
    case "$1" in
      --persist)
        persistent=true
        ;;
      --list)
        list_snapshots
        return
        ;;
      --clean)
        clean_cache
        return
        ;;
      --storage)
        show_storage_status
        return
        ;;
      --check-deps)
        check_dependencies_only
        return
        ;;
      --install-deps)
        install_arch_dependencies
        return
        ;;
      --ssh)
        connect_ssh
        return
        ;;
      --help | -h)
        print_usage
        return
        ;;
      --*)
        print_error "Unknown option: $1"
        print_usage >&2
        return 2
        ;;
      *)
        if [[ $revision_was_set == true ]]; then
          print_error "Only one branch or commit may be specified"
          return 2
        fi
        revision="$1"
        revision_was_set=true
        ;;
    esac
    shift
  done

  run_revision "$revision" "$persistent"
}

main "$@"
