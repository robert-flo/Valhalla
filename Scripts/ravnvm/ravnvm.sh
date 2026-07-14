#!/usr/bin/env bash

# shellcheck disable=SC1091
if ! source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..." >&2
    exit 1
fi

# ╭──────────────────────────────────────────────────────────────────────────────╮
# │                                                                              │
# │                 RavnVM — QEMU/KVM Development Environment                   │
# │                                                                              │
# │       Development tool for testing RaVN branches and commits in VMs         │
# │                                                                              │
# ╰──────────────────────────────────────────────────────────────────────────────╯
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         RavnVM — Documentation                              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# USAGE
#   ravnvm              — Validate the environment and open the menu
#   ravnvm <revision>   — Run a branch or commit directly
#   ravnvm --persist    — Run with persistent VM changes
#   ravnvm --repo URL   — Run a repository other than RaVN
#
# DIRECT OPTIONS
#   --list              — List cached snapshots
#   --storage           — Show VM storage usage
#   --clean             — Remove cached VM state
#   --check-deps        — Check host dependencies
#   --install-deps      — Install host dependencies on Arch Linux
#   --install-ssh-alias — Configure the `ssh ravnvm` host alias
#   --help              — Show command help
#
# EXTERNAL REPOSITORY EXAMPLES
#   ravnvm --repo robert-flo/Valhalla master
#   RAVNVM_REPO=https://github.com/robert-flo/Valhalla.git ravnvm master
#   make dev-vm-external REPO=robert-flo/Valhalla REF=master

set -e

ACTIVE_QEMU_PID=""
TEMPORARY_PATHS=()
VM_LOCK_FD=""

function cleanup_runtime() {
  local temporary_path=""

  if [[ -n $ACTIVE_QEMU_PID ]] && kill -0 "$ACTIVE_QEMU_PID" 2> /dev/null; then
    kill "$ACTIVE_QEMU_PID" 2> /dev/null || true
    wait "$ACTIVE_QEMU_PID" 2> /dev/null || true
  fi
  ACTIVE_QEMU_PID=""

  for temporary_path in "${TEMPORARY_PATHS[@]}"; do
    rm -f -- "$temporary_path"
  done
  TEMPORARY_PATHS=()
}

function handle_interrupt() {
  print_warn "RavnVM interrupted; temporary state was removed safely"
  exit 130
}

function register_temporary_path() {
  TEMPORARY_PATHS+=("$1")
}

function acquire_vm_lock() {
  exec {VM_LOCK_FD}> "$CACHE_DIR/session.lock"
  if ! flock -n "$VM_LOCK_FD"; then
    exec {VM_LOCK_FD}>&-
    VM_LOCK_FD=""
    print_error "Another RavnVM session is already active; close it before starting a new VM"
    return 1
  fi
}

function release_vm_lock() {
  if [[ -n $VM_LOCK_FD ]]; then
    flock -u "$VM_LOCK_FD"
    exec {VM_LOCK_FD}>&-
    VM_LOCK_FD=""
  fi
}

trap handle_interrupt INT TERM
trap cleanup_runtime EXIT

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Configuration                                                                │
# └──────────────────────────────────────────────────────────────────────────────┘
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ravnvm"
BASE_IMAGE="$CACHE_DIR/archbase.qcow2"
SNAPSHOTS_DIR="$CACHE_DIR/snapshots"
DEFAULT_RAVNVM_REPO="https://github.com/robert-flo/RaVN.git"
RAVNVM_REPO="${RAVNVM_REPO:-$DEFAULT_RAVNVM_REPO}"
SSH_PORT=2222
SSH_READY_TIMEOUT="${RAVNVM_SSH_READY_TIMEOUT:-120}"
if [[ ! $SSH_READY_TIMEOUT =~ ^[0-9]+$ ]]; then
    SSH_READY_TIMEOUT=120
fi
# Required packages for Arch Linux
ARCH_PACKAGES=(
    "qemu-desktop"
    "curl"
    "python"
    "git"
)

# Create cache directories
mkdir -p "$CACHE_DIR" "$SNAPSHOTS_DIR"

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Environment & Dependencies                                                   │
# └──────────────────────────────────────────────────────────────────────────────┘

function detect_os() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        if [[ $ID == "nixos" ]]; then
            echo "nixos"
    elif     [[ $ID == "arch" ]] || [[ ${ID_LIKE:-} == *arch* ]] || command -v pacman > /dev/null 2>&1; then
            echo "arch"
    else
            echo "unknown"
    fi
  elif   command -v nixos-version > /dev/null 2>&1; then
        echo "nixos"
  elif   command -v pacman > /dev/null 2>&1; then
        echo "arch"
  else
        echo "unknown"
  fi
}

function print_usage() {
    echo "RavnVM - Simplified VM tool for RaVN contributors"
    echo "Supports: Arch Linux, Arch-based distros, NixOS"
    echo ""
    echo "Usage: ravnvm [OPTIONS] [BRANCH/COMMIT]"
    echo ""
    echo "Arguments:"
    echo "  BRANCH/COMMIT            Git branch or commit hash (default: master)"
    echo ""
    echo "Options:"
    echo "  --persist               Make VM changes persistent"
    echo "  --repo URL              Use another Git repository (default: RaVN)"
    echo "  --list                  List available snapshots"
    echo "  --storage               Show VM storage usage"
    echo "  --clean                 Clean all cached data"
    echo "  --install-deps          Install required dependencies (Arch only)"
    echo "  --check-deps            Check if dependencies are installed"
    echo "  --install-ssh-alias     Configure the 'ssh ravnvm' host alias"
    echo "  --ssh                   Connect to the running VM via SSH"
    echo "  --help                  Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  VM_MEMORY=4G            Set VM memory (default: 4G)"
    echo "  VM_CPUS=2               Set VM CPU count (default: 2)"
    echo "  VM_EXTRA_ARGS=\"args\"     Add extra QEMU arguments"
    echo "  VM_QEMU_OVERRIDE=\"cmd\"   Override entire QEMU command (\$VM_DISK substituted)"
    echo ""
    echo "Examples:"
    echo "  ravnvm                  # Run master branch"
    echo "  ravnvm --persist        # Run master branch (persistent)"
    echo "  ravnvm feature-branch   # Run specific branch"
    echo "  ravnvm abc123           # Run specific commit"
    echo "  ravnvm --persist dev    # Run dev branch with persistence"
    echo "  ravnvm --repo robert-flo/Valhalla master"
    echo "  RAVNVM_REPO=https://github.com/robert-flo/Valhalla.git ravnvm master"
    echo "  make dev-vm-external REPO=robert-flo/Valhalla REF=master"
    echo ""
    echo "OS-specific notes:"
    echo "  Arch Linux: Missing packages will be auto-detected and offered for install"
    echo "  NixOS: automatically installs dependencies"
}

function normalize_repository_url() {
    local repository="$1"

    if [[ $repository =~ ^[^/:]+/[^/:]+$ ]]; then
        repository="https://github.com/${repository}.git"
  elif   [[ $repository =~ ^https://github\.com/[^/]+/[^/]+$ ]]; then
        repository="${repository}.git"
  fi

    if [[ ! $repository =~ ^https://[^[:space:]]+\.git$ ]]; then
        print_error "Invalid repository. Use owner/name or an HTTPS .git URL" >&2
        return 1
  fi

    printf '%s\n' "$repository"
}

function check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Please don't run this script as root"
        local os
        os=$(detect_os)
        if [[ "$os" == "arch" ]]; then
            print_info "Use --install-deps to install dependencies with sudo"
    fi
        exit 1
  fi
}

function check_dependencies() {
    local os
    os=$(detect_os)

    case "$os" in
        "nixos")
            check_nixos_dependencies
            ;;
        "arch")
            check_arch_dependencies
            ;;
        *)
            print_warn "Unsupported OS. This script supports Arch Linux and NixOS."
            check_common_commands
            ;;
  esac
}

function check_common_commands() {
    local missing_commands=()

    for cmd in qemu-system-x86_64 qemu-img curl git; do
        if ! command -v "$cmd" > /dev/null 2>&1; then
            missing_commands+=("$cmd")
    fi
  done

    if ! command -v python3 > /dev/null 2>&1 && ! command -v python > /dev/null 2>&1; then
        missing_commands+=("python")
  fi

    if [ ${#missing_commands[@]} -gt 0 ]; then
        print_error "Missing required commands: ${missing_commands[*]}"
        print_info "Please ensure qemu, curl, python, and git are installed."
        return 1
  fi

    return 0
}

function check_nixos_dependencies() {
    local missing_commands=()

    # Check for required commands
    for cmd in qemu-system-x86_64 qemu-img curl git; do
        if ! command -v "$cmd" > /dev/null 2>&1; then
            missing_commands+=("$cmd")
    fi
  done

    if ! command -v python3 > /dev/null 2>&1 && ! command -v python > /dev/null 2>&1; then
        missing_commands+=("python")
  fi

    if [ ${#missing_commands[@]} -gt 0 ]; then
        print_error "Missing required commands: ${missing_commands[*]}"
        print_info "On NixOS, use nix-shell -p qemu curl python3 git or add them to configuration.nix."
        return 1
  fi

    # Check if KVM is available
    if [ ! -r /dev/kvm ]; then
        print_warn "KVM not available. VM will run slower."
        print_info "On NixOS, ensure virtualisation.libvirtd.enable = true; in configuration.nix."
        print_info "Alternatively, add your user to the kvm group and rebuild."
  fi

    return 0
}

function check_arch_dependencies() {
    local missing_packages=()

    for package in "${ARCH_PACKAGES[@]}"; do
        if ! pacman -Q "$package" &> /dev/null; then
            missing_packages+=("$package")
    fi
  done

    if [ ${#missing_packages[@]} -gt 0 ]; then
        print_error "Missing required packages: ${missing_packages[*]}"
        read -p "Would you like to install them now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_arch_packages "${missing_packages[@]}"
    else
            print_info "Install them manually with: sudo pacman -S ${missing_packages[*]}"
            return 1
    fi
  fi

    # Check if KVM is available
    if [ ! -r /dev/kvm ]; then
        print_warn "KVM not available. VM will run slower."
        print_info "Make sure your user is in the 'kvm' group: sudo usermod -a -G kvm $USER"
        print_info "Then logout and login again."
  fi

    return 0
}

function install_arch_packages() {
    local packages=("$@")

    print_step "Installing missing packages: ${packages[*]}"

    # Update package database
    print_step "Updating package database..."
    sudo pacman -Sy

    # Install required packages
    print_step "Installing packages..."
    sudo pacman -S --needed "${packages[@]}"

    # Add user to kvm group if it exists and we installed qemu
    if [[ " ${packages[*]} " =~ " qemu-desktop " ]] && getent group kvm > /dev/null; then
        print_step "Adding user to kvm group..."
        sudo usermod -a -G kvm "$USER"
        print_warn "Please logout and login again for group changes to take effect"
  fi

    print_success "Packages installed successfully"
}

function install_all_arch_dependencies() {
    local os
    os=$(detect_os)

    if [[ "$os" != "arch" ]]; then
        print_error "--install-deps is only supported on Arch Linux"
        print_info "Current OS: $os"
        exit 1
  fi

    print_step "Installing all RavnVM dependencies..."
    install_arch_packages "${ARCH_PACKAGES[@]}"
    print_info "You may need to reboot or logout/login for all changes to take effect"
}

function check_deps_only() {
    local os
    os=$(detect_os)
    print_section "Checking RavnVM dependencies"
    print_info "Detected OS: $os"

    if check_dependencies; then
        print_success "All dependencies are installed"

        # Check additional system info
        print_section "System Information"
        print_info "CPU cores: $(nproc)"
        print_info "Memory: $(free -h | awk '/^Mem:/ {print $2}' 2> /dev/null || echo "Unknown")"
        print_info "KVM available: $([ -r /dev/kvm ] && echo "Yes" || echo "No")"

        if command -v qemu-system-x86_64 > /dev/null 2>&1; then
            print_info "QEMU version: $(qemu-system-x86_64 --version | head -1)"
    fi

        return 0
  else
        return 1
  fi
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ QEMU Runtime                                                                 │
# └──────────────────────────────────────────────────────────────────────────────┘

function get_qemu_command() {
    # Try to find qemu-system-x86_64 in common locations
    if command -v qemu-system-x86_64 > /dev/null 2>&1; then
        echo "qemu-system-x86_64"
  elif   [ -x "/usr/bin/qemu-system-x86_64" ]; then
        echo "/usr/bin/qemu-system-x86_64"
  elif   [ -x "/usr/local/bin/qemu-system-x86_64" ]; then
        echo "/usr/local/bin/qemu-system-x86_64"
  else
        echo "qemu-system-x86_64"  # fallback
  fi
}

function get_python_command() {
    # Try to find python in common locations
    if command -v python3 > /dev/null 2>&1; then
        echo "python3"
  elif   command -v python > /dev/null 2>&1; then
        echo "python"
  else
        echo "python3"  # fallback
  fi
}

function run_qemu_vm() {
    local vm_disk="$1"
    local memory="${2:-4G}"
    local cpus="${3:-2}"
    local extra_args="${4:-}"
    local execution_mode="${5:-foreground}"
    local qemu_cmd
    qemu_cmd=$(get_qemu_command)

    # Check if user wants to override QEMU command entirely
    if [ -n "${VM_QEMU_OVERRIDE:-}" ]; then
        print_info "Using custom QEMU command override..."
        # Substitute $VM_DISK in the override command
        local qemu_override_cmd
        qemu_override_cmd=${VM_QEMU_OVERRIDE//\$VM_DISK/$vm_disk}
        if [[ $execution_mode == "background" ]]; then
            bash -c "exec $qemu_override_cmd" &
            ACTIVE_QEMU_PID=$!
            return 0
    fi
        eval "$qemu_override_cmd"
  else
        # Build QEMU command arguments
        local qemu_args=(
            -m "$memory"
            -smp "$cpus"
            -drive "file=$vm_disk,format=qcow2,if=virtio"
            -device virtio-vga-gl
            -display "gtk,gl=on,grab-on-hover=on"
            -boot "menu=on"
    )

        # Add KVM-specific arguments
        if [ -r /dev/kvm ]; then
            qemu_args+=(-enable-kvm -cpu host)
    else
            qemu_args+=(-cpu qemu64)
    fi

        # Add network arguments if extra_args are provided
        if [ -n "$extra_args" ]; then
            qemu_args+=(-device "virtio-net,netdev=net0" -netdev "user,id=net0,$extra_args")
    fi

        # Add any extra VM arguments
        if [ -n "${VM_EXTRA_ARGS:-}" ]; then
            # shellcheck disable=SC2086
            read -ra extra_vm_args <<< "$VM_EXTRA_ARGS"
            qemu_args+=("${extra_vm_args[@]}")
    fi

        # Background mode keeps the real QEMU PID available for safe interruption.
        if [[ $execution_mode == "background" ]]; then
            "$qemu_cmd" "${qemu_args[@]}" 2> "$CACHE_DIR/qemu.log" &
            ACTIVE_QEMU_PID=$!
            return 0
    fi

        # Execute QEMU with all arguments and redirect stderr to log
        if ! "$qemu_cmd" "${qemu_args[@]}" 2> "$CACHE_DIR/qemu.log"; then
            print_error "QEMU failed to start. Check details in $CACHE_DIR/qemu.log"
    fi
  fi
}

function wait_for_guest_ssh() {
    local qemu_pid="$1"
    local deadline=$((SECONDS + SSH_READY_TIMEOUT))

    while ((SECONDS <= deadline)); do
        if ssh-keyscan -p "$SSH_PORT" 127.0.0.1 2> /dev/null | grep -q "ssh-"; then
            return 0
    fi

        if ! kill -0 "$qemu_pid" 2> /dev/null; then
            wait "$qemu_pid" 2> /dev/null || true
            ACTIVE_QEMU_PID=""
            print_error "The setup VM stopped before SSH became available"
            return 1
    fi

        sleep 1
  done

    print_error "Timed out waiting for the setup VM SSH server"
    return 1
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Images & Snapshots                                                           │
# └──────────────────────────────────────────────────────────────────────────────┘

function get_latest_arch_image_url() {
    echo "https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-basic.qcow2"
}

function download_archbox() {
    local partial_image="${BASE_IMAGE}.part"

    if [ ! -f "$BASE_IMAGE" ]; then
        print_step "Downloading Arch Linux base image..."
        local latest_url
        latest_url=$(get_latest_arch_image_url)
        rm -f -- "$partial_image"
        register_temporary_path "$partial_image"
        if ! curl -fL "$latest_url" -o "$partial_image"; then
            rm -f -- "$partial_image"
            print_error "Unable to download the Arch Linux base image"
            return 1
    fi
        if ! mv -- "$partial_image" "$BASE_IMAGE"; then
            print_error "Unable to store the Arch Linux base image"
            return 1
    fi
        print_success "Base image downloaded successfully"
  fi
}

function get_snapshot_name() {
    local ref="$1"
    if [ -z "$ref" ]; then
        echo "master"
  else
        # Sanitize branch/commit name for filename
        echo "${ref//[^a-zA-Z0-9._-]/_}"
  fi
}

function create_ravn_snapshot() {
    local ref="${1:-master}"
    local setup_completed=""
    local snapshot_name
    snapshot_name=$(get_snapshot_name "$ref")
    local snapshot_path="$SNAPSHOTS_DIR/ravn-$snapshot_name.qcow2"
    local qemu_cmd
    qemu_cmd=$(get_qemu_command)

    # Check if snapshot already exists
    if [ -f "$snapshot_path" ]; then
        print_info "Snapshot for '$ref' already exists"
        return 0
  fi

    echo "${ICON_BUILD} Creating RaVN snapshot for '$ref'..."

    # Create temporary VM image for setup
    local temp_image="$CACHE_DIR/temp-setup.qcow2"
    register_temporary_path "$temp_image"
    qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMAGE" "$temp_image"

    # Create setup script that will be available in the VM
    local setup_script="$CACHE_DIR/setup.sh"
    register_temporary_path "$setup_script"
    cat > "$setup_script" << SETUP_EOF
#!/bin/bash
set -e

guest_step() { printf '▶ %s\n' "$*"; }
guest_info() { printf '  %s\n' "$*"; }
guest_warn() { printf '⚠ %s\n' "$*" >&2; }
guest_success() { printf '✓ %s\n' "$*"; }

guest_step "Setting up RaVN environment for branch/commit: $ref"

# Set root password for convenience (using 'arch' as requested for simplicity)
guest_step "Setting root password..."
echo "root:arch" | sudo chpasswd

# Update system and install dependencies
guest_step "Updating system and installing dependencies..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm git base-devel openssh curl kitty-terminfo

# Configure SSH
guest_step "Configuring SSH..."
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl enable sshd

# Clone or update RaVN repository
guest_step "Setting up RaVN repository..."
cd /home/arch
if [ -d "RaVN" ]; then
    guest_info "RaVN directory exists, updating..."
    cd RaVN
    git remote set-url origin "$RAVNVM_REPO" 2>/dev/null || true
    git fetch origin
    git reset --hard HEAD  # Reset any local changes
else
    guest_info "Cloning RaVN repository..."
    git clone "$RAVNVM_REPO" RaVN
    cd RaVN
fi

# Checkout specific branch/commit if provided
if [ "$ref" != "master" ]; then
    guest_step "Checking out branch/commit: $ref"
    git fetch origin

    # Check if it's a branch or commit
    if git show-ref --verify --quiet "refs/remotes/origin/$ref" 2>/dev/null; then
        guest_info "Found branch: $ref"
        # Delete local branch if it exists, then create fresh one
        git branch -D "$ref" 2>/dev/null || true
        git checkout -b "$ref" "origin/$ref"
    else
        guest_info "Treating as commit: $ref"
        git checkout "$ref"
    fi
else
    guest_step "Using master branch"
    git checkout master
    git pull origin master
fi

echo ""
guest_success "RaVN repository ready!"

# Check if RaVN is already installed
if [ -f "/home/arch/.config/hypr/hyprland.conf" ] && [ -f "/home/arch/.config/hyde/config.toml" ]; then
    guest_warn "RaVN appears to already be installed."
    guest_info "Configuration files found. Skipping installation."
    guest_info "To reinstall, remove ~/.config/hypr and ~/.config/hyde first."
else
    guest_step "Starting RaVN installation..."
    cd /home/arch/RaVN/Scripts
    ./install.sh
    guest_success "RaVN installation complete!"
fi

echo ""
guest_success "Setup complete!"
guest_info "Please shutdown the VM now by running: sudo poweroff"
guest_info "This will create the snapshot for future use."
guest_info "If something went wrong, you can re-run this script safely."
SETUP_EOF

    chmod +x "$setup_script"

    echo ""
    echo "${ICON_VM}  Starting VM for RaVN installation..."
    echo "${ICON_INSTRUCTIONS} SETUP INSTRUCTIONS:"
    echo "   1. The VM will boot in the background."
    echo "   2. The setup script will be automatically copied to /home/arch/setup.sh via SSH (port ${SSH_PORT})."
    echo "   3. Once copied, login to the VM (arch/arch) or SSH into it: ssh arch@127.0.0.1 -p ${SSH_PORT} (or ssh ravnvm)"
    echo "   4. Run the setup script manually: chmod +x ./setup.sh && ./setup.sh"
    echo "   5. When the installation finishes, power off the VM: sudo poweroff"
    echo "      (This will automatically complete the snapshot creation on the host)"
    echo ""

    # Start VM for setup in background with SSH port forward
    run_qemu_vm "$temp_image" "${VM_MEMORY:-4G}" "${VM_CPUS:-2}" "hostfwd=tcp::${SSH_PORT}-:22" "background"
    local qemu_pid="$ACTIVE_QEMU_PID"

    echo "${ICON_WAITING} Waiting for VM SSH server to be fully ready..."
    if ! wait_for_guest_ssh "$qemu_pid"; then
        cleanup_runtime
        return 1
  fi
    print_success "SSH server is ready."

    print_step "Copying setup script to VM..."
    # We use StrictHostKeyChecking=no and UserKnownHostsFile=/dev/null to avoid host key warnings
    local ssh_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
    if command -v sshpass > /dev/null 2>&1; then
        sshpass -p 'arch' scp -P "$SSH_PORT" "${ssh_opts[@]}" "$setup_script" arch@127.0.0.1:/home/arch/setup.sh
  else
        print_info "Tip: Install 'sshpass' to avoid entering the 'arch' password manually."
        scp -P "$SSH_PORT" "${ssh_opts[@]}" "$setup_script" arch@127.0.0.1:/home/arch/setup.sh
  fi
    print_success "setup.sh copied successfully to /home/arch/setup.sh"
    print_info "Login to the VM and run: chmod +x ./setup.sh && ./setup.sh"

    # Wait for QEMU process to finish cleanly
    if ! wait "$qemu_pid"; then
        ACTIVE_QEMU_PID=""
        print_error "The setup VM exited with an error; no snapshot was cached"
        return 1
  fi
    ACTIVE_QEMU_PID=""

    echo ""
    read -r -p "${LIGHT_GRAY}Did the RaVN setup complete successfully? [y/N]${NC} " setup_completed
    if [[ ! $setup_completed =~ ^[Yy]$ ]]; then
        print_error "Setup was not confirmed; no snapshot was cached"
        return 1
  fi

    echo ""
    print_step "Converting VM to snapshot..."

    # Convert temporary image to final snapshot
    if ! qemu-img convert -O qcow2 "$temp_image" "$snapshot_path"; then
        rm -f -- "$snapshot_path"
        print_error "Unable to create the revision snapshot"
        return 1
  fi

    # Cleanup
    rm -f "$temp_image" "$setup_script"

    print_success "Snapshot created: ravn-$snapshot_name"
    print_info "You can now run: ravnvm $ref"
}

function run_vm() {
    local ref="${1:-master}"
    local persistent="${2:-false}"
    local snapshot_name
    snapshot_name=$(get_snapshot_name "$ref")
    local snapshot_path="$SNAPSHOTS_DIR/ravn-$snapshot_name.qcow2"
    local qemu_cmd
    qemu_cmd=$(get_qemu_command)

    # Ensure snapshot exists
    if [ ! -f "$snapshot_path" ]; then
        echo "${ICON_SNAPSHOT} Snapshot for '$ref' not found, creating it..."
        if ! create_ravn_snapshot "$ref"; then
            return 1
    fi
  fi

    local vm_disk
    if [ "$persistent" = "true" ]; then
        print_info "Running in persistent mode - changes will be saved"
        vm_disk="$snapshot_path"
  else
        print_info "Running in non-persistent mode - changes will be discarded"
        vm_disk="$(mktemp -p "$CACHE_DIR" overlay.XXXXXX.qcow2)"
        register_temporary_path "$vm_disk"
        qemu-img create -f qcow2 -F qcow2 -b "$snapshot_path" "$vm_disk"
  fi

    print_step "Starting RaVN VM (branch/commit: $ref)..."
    print_info "Login: arch / arch"
    print_info "SSH: ssh arch@127.0.0.1 -p ${SSH_PORT} (or run: ravnvm --ssh or ssh ravnvm)"

    # Run VM with SSH port forwarding
    run_qemu_vm "$vm_disk" "${VM_MEMORY:-4G}" "${VM_CPUS:-2}" "hostfwd=tcp::${SSH_PORT}-:22"

    if [ "$persistent" != "true" ]; then
        rm -f -- "$vm_disk"
  fi
}

function list_snapshots() {
    local snapshots=""

    print_section "Available RaVN snapshots"
    if [ -d "$SNAPSHOTS_DIR" ]; then
        snapshots=$(find "$SNAPSHOTS_DIR" -name "ravn-*.qcow2" -exec basename {} \; |
            sed 's/^ravn-//' | sed 's/\.qcow2$//' | sort)

        if [ -n "$snapshots" ]; then
            printf '%s\n' "$snapshots"
    else
            print_info "No snapshots found"
    fi
  else
        print_info "No snapshots found"
  fi
}

function clean_cache() {
    echo "${ICON_CLEANING} Cleaning RavnVM cache (preserving base image)..."
    if [ ! -d "$CACHE_DIR" ]; then
        print_error "RavnVM cache directory not found"
        return 1
  fi

    if ! find "$CACHE_DIR" -mindepth 1 -maxdepth 1 \
        ! -name "archbase.qcow2" ! -name "session.lock" -exec rm -rf {} +; then
        print_error "Unable to clean RavnVM cache"
        return 1
  fi

    if ! mkdir -p "$SNAPSHOTS_DIR"; then
        print_error "Unable to recreate snapshots directory"
        return 1
  fi

    if [ -f "$BASE_IMAGE" ]; then
        print_success "Cache cleaned; base image preserved"
  else
        print_success "Cache cleaned"
  fi
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Interactive Interface                                                        │
# └──────────────────────────────────────────────────────────────────────────────┘

function press_enter_to_continue() {
  printf '\n'
  read -r -p "Press Enter to continue..." _
}

function print_ravnvm_banner() {
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
  │       RavnVM — QEMU/KVM Development Environment    │
  │                                                    │
BANNER_EOF
  echo -e "  │       ${GRAY}by Roberto Flores ${WHITE}@robert-flo${CYAN}                │"
  cat << 'BANNER_EOF'
  │                                                    │
  ╰────────────────────────────────────────────────────╯
BANNER_EOF
  echo -e "${NC}"
}

function format_bytes() {
  local bytes="${1:-0}"

  awk -v bytes="$bytes" 'BEGIN {
    split("B KiB MiB GiB TiB", units)
    unit = 1
    unit_index = 1
    while (bytes >= 1024 && unit_index < 5) {
      bytes /= 1024
      unit++
      unit_index++
    }
    printf "%.2f %s", bytes, units[unit_index]
  }'
}

function show_storage_status() {
  local cache_bytes="0"
  local filesystem_total="0"
  local filesystem_used="0"
  local filesystem_available="0"
  local filesystem_percent="0"
  local storage_status=""

  cache_bytes=$(du -s -B1 "$CACHE_DIR" 2> /dev/null | awk '{print $1}' || echo "0")
  read -r filesystem_total filesystem_used filesystem_available filesystem_percent < <(
    df -P -B1 "$CACHE_DIR" 2> /dev/null | awk 'NR == 2 {
      gsub("%", "", $5)
      print $2, $3, $4, $5
    }'
  ) || true

  if ((filesystem_percent >= 90)); then
    storage_status="${RED}${ICON_DIAGNOSTIC_ERROR} Critical${NC}"
  elif ((filesystem_percent >= 80)); then
    storage_status="${YELLOW}${ICON_DIAGNOSTIC_WARNING} High usage${NC}"
  else
    storage_status="${GREEN}${ICON_CHECK} Available${NC}"
  fi

  print_section "${ICON_UI_STORAGE} Storage ${storage_status}"
  print_info "${ICON_UI_DATABASE} VM cache: $(format_bytes "$cache_bytes")"
  print_info "${ICON_UI_STORAGE} Disk: $(format_bytes "$filesystem_used") used / $(format_bytes "$filesystem_total") (${filesystem_percent}%)"
  print_info "${ICON_UI_DOWNLOAD} Free: $(format_bytes "$filesystem_available")"

  if ((filesystem_percent >= 90)); then
    print_error "Storage critically low; clean old VM snapshots before continuing"
  elif ((filesystem_percent >= 80)); then
    print_warn "Storage usage is high; review VM snapshots before creating another"
  fi
}

function validate_command() {
  local command_name="$1"

  if command_exists "$command_name"; then
    print_success "$command_name"
    return 0
  fi

  print_error "$command_name not found"
  return 1
}

function validate_environment() {
  local command_name=""
  local validation_failed=0

  print_section "${ICON_UI_GEAR} Validating Environment"
  for command_name in qemu-system-x86_64 qemu-img curl git; do
    if ! validate_command "$command_name"; then
      validation_failed=1
    fi
  done

  if command_exists python3 || command_exists python; then
    print_success "python"
  else
    print_error "python not found"
    validation_failed=1
  fi

  if [[ -d "$CACHE_DIR" && -w "$CACHE_DIR" ]]; then
    print_success "RavnVM cache directory"
  else
    print_error "RavnVM cache directory is not writable"
    validation_failed=1
  fi

  if [[ -r /dev/kvm ]]; then
    print_success "KVM acceleration"
  else
    print_warn "KVM unavailable; QEMU will run without hardware acceleration"
  fi

  show_storage_status
  return "$validation_failed"
}

function recover_environment() {
  local recovery_choice=""

  while ! validate_environment; do
    print_section "${ICON_DIAGNOSTIC_ERROR} Required dependencies missing"
    echo -e "  ${GREEN}1${NC}  ${ICON_UI_PACKAGE}  Install dependencies"
    echo -e "  ${GREEN}q${NC}  ${ICON_UI_CLOSE}  Exit"
    echo ""
    read -r -p "${LIGHT_GRAY}Selection:${NC} " recovery_choice

    case "$recovery_choice" in
      1)
        if ! install_all_arch_dependencies; then
          print_error "Dependency installation failed"
          press_enter_to_continue
        fi
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

  return 0
}

function show_menu() {
  clear || true
  print_ravnvm_banner
  print_section "${ICON_UI_COMMAND} Choose an action"
  echo -e "  ${GREEN}1${NC}  ${ICON_GIT_BRANCH}  Run master branch"
  echo -e "  ${GREEN}2${NC}  ${ICON_GIT_BRANCH}  Run dev branch"
  echo -e "  ${GREEN}3${NC}  ${ICON_GIT_BRANCH}  Run current branch"
  echo -e "  ${GREEN}4${NC}  ${ICON_GIT_BRANCH}  Run other branch or commit"
  echo -e "  ${GREEN}5${NC}  ${ICON_UI_STORAGE}  Show VM storage usage"
  echo -e "  ${GREEN}6${NC}  ${ICON_UI_TRASH}  Clean VM cache"
  echo -e "  ${GREEN}7${NC}  ${ICON_UI_LIST}  List VM snapshots"
  echo -e "  ${GREEN}8${NC}  ${ICON_UI_GEAR}  Configure RAM and CPU"
  echo -e "  ${GREEN}9${NC}  ${ICON_DIAGNOSTIC_INFO}  Show RavnVM usage"
  echo -e "  ${GREEN}10${NC} ${ICON_UI_TERMINAL}  Connect to VM via SSH"
  echo -e "  ${GREEN}11${NC} ${ICON_UI_BOOKMARK}  Install SSH alias"
  echo -e "  ${GREEN}12${NC} ${ICON_GIT_GITHUB}  Run external repository"
  echo -e "  ${GREEN}q${NC}  ${ICON_UI_CLOSE}  Exit"
  echo ""
  read -r -p "${LIGHT_GRAY}Selection:${NC} " MENU_CHOICE
}

function get_current_branch() {
  local current_branch=""

  current_branch=$(git branch --show-current 2> /dev/null || true)
  printf '%s\n' "$current_branch"
}

function select_execution_mode() {
  local mode_choice=""

  SELECTED_PERSISTENCE=""

  print_section "${ICON_UI_PLAY} Choose VM mode"
  echo -e "  ${GREEN}1${NC}  ${ICON_UI_PLAY}  Ephemeral"
  echo -e "  ${GREEN}2${NC}  ${ICON_UI_SAVE}  Persistent"
  echo -e "  ${GREEN}q${NC}  ${ICON_UI_ARROW_LEFT}  Back"
  echo ""
  read -r -p "${LIGHT_GRAY}Selection:${NC} " mode_choice

  case "$mode_choice" in
    1)
      SELECTED_PERSISTENCE="false"
      ;;
    2)
      SELECTED_PERSISTENCE="true"
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

function configure_vm_resources() {
  local current_memory="${VM_MEMORY:-4G}"
  local current_cpus="${VM_CPUS:-2}"
  local requested_memory=""
  local requested_cpus=""

  print_section "${ICON_UI_GEAR} Configure VM resources"
  read -r -p "${LIGHT_GRAY}RAM [${current_memory}]:${NC} " requested_memory
  read -r -p "${LIGHT_GRAY}CPUs [${current_cpus}]:${NC} " requested_cpus

  VM_MEMORY="${requested_memory:-$current_memory}"
  VM_CPUS="${requested_cpus:-$current_cpus}"

  if ! [[ $VM_CPUS =~ ^[1-9][0-9]*$ ]]; then
    print_error "CPU count must be a positive integer"
    VM_CPUS="$current_cpus"
    return 1
  fi

  export VM_MEMORY VM_CPUS
  print_success "Session resources: ${VM_MEMORY} RAM, ${VM_CPUS} CPUs"
}

function run_selected_revision() {
  local revision="$1"

  if ! select_execution_mode; then
    return 0
  fi

  run_vm_command "$revision" "$SELECTED_PERSISTENCE" || true
  press_enter_to_continue
}

function run_custom_revision() {
  local custom_revision=""

  read -r -p "${LIGHT_GRAY}Branch or commit:${NC} " custom_revision
  if [[ -z $custom_revision ]]; then
    print_error "A branch or commit is required"
    press_enter_to_continue
    return 1
  fi

  run_selected_revision "$custom_revision"
}

function run_external_repository() {
  local repository_input=""
  local external_repository=""
  local external_revision=""
  local previous_repository="$RAVNVM_REPO"

  print_section "Run external repository"
  print_info "Default RaVN repository: $DEFAULT_RAVNVM_REPO"
  read -r -p "${LIGHT_GRAY}Repository URL or owner/name:${NC} " repository_input
  if [[ -z $repository_input ]]; then
    print_error "A repository is required"
    press_enter_to_continue
    return 1
  fi

  if ! external_repository=$(normalize_repository_url "$repository_input"); then
    press_enter_to_continue
    return 1
  fi

  read -r -p "${LIGHT_GRAY}Branch or commit [master]:${NC} " external_revision
  external_revision="${external_revision:-master}"
  RAVNVM_REPO="$external_repository"
  print_info "Using external repository: $RAVNVM_REPO"
  print_info "Using revision: $external_revision"
  run_selected_revision "$external_revision"
  RAVNVM_REPO="$previous_repository"
}

function connect_ssh() {
  ssh -p "$SSH_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null arch@127.0.0.1
}

function install_ssh_alias() {
  local ssh_directory="$HOME/.ssh"
  local ssh_config="$ssh_directory/config"
  local temporary_config=""
  local block_begin="# >>> RavnVM managed SSH alias >>>"
  local block_end="# <<< RavnVM managed SSH alias <<<"

  mkdir -p "$ssh_directory"
  chmod 700 "$ssh_directory"
  touch "$ssh_config"

  temporary_config=$(mktemp "$ssh_directory/config.XXXXXX")
  register_temporary_path "$temporary_config"

  {
    printf '%s\n' "$block_begin"
    printf 'Host ravnvm\n'
    printf '    HostName 127.0.0.1\n'
    printf '    User arch\n'
    printf '    Port %s\n' "$SSH_PORT"
    printf '    StrictHostKeyChecking no\n'
    printf '    UserKnownHostsFile /dev/null\n'
    printf '%s\n' "$block_end"

    awk -v block_begin="$block_begin" -v block_end="$block_end" '
      $0 == block_begin { in_managed_block = 1; next }
      $0 == block_end { in_managed_block = 0; next }
      in_managed_block { next }
      !started && $0 == "" { next }
      { started = 1; lines[++count] = $0 }
      END {
        if (count > 0) print ""
        for (line = 1; line <= count; line++) print lines[line]
      }
    ' "$ssh_config"
  } > "$temporary_config"

  chmod 600 "$temporary_config"
  mv -- "$temporary_config" "$ssh_config"
  print_success "SSH alias installed; connect with: ssh ravnvm"
}

function run_vm_command() {
  local revision="${1:-master}"
  local persistent_mode="${2:-false}"
  local run_status=0

  if ! check_dependencies; then
    return 1
  fi

  if ! acquire_vm_lock; then
    return 1
  fi

  if ! download_archbox; then
    release_vm_lock
    return 1
  fi

  run_vm "$revision" "$persistent_mode" || run_status=$?
  release_vm_lock
  return "$run_status"
}

function run_interactive_menu() {
  local choice=""
  local current_branch=""

  while true; do
    show_menu
    choice="$MENU_CHOICE"

    case "$choice" in
      1)
        run_selected_revision "master"
        ;;
      2)
        run_selected_revision "dev"
        ;;
      3)
        current_branch=$(get_current_branch)
        run_selected_revision "${current_branch:-master}"
        ;;
      4)
        run_custom_revision || true
        ;;
      5)
        show_storage_status || true
        press_enter_to_continue
        ;;
      6)
        printf '\n'
        clean_cache || true
        press_enter_to_continue
        ;;
      7)
        list_snapshots || true
        press_enter_to_continue
        ;;
      8)
        configure_vm_resources || true
        press_enter_to_continue
        ;;
      9)
        print_usage
        press_enter_to_continue
        ;;
      10)
        if ! connect_ssh; then
          print_warn "SSH session ended; the VM may have stopped or become unavailable"
        fi
        press_enter_to_continue
        ;;
      11)
        if ! install_ssh_alias; then
          print_error "Unable to install the SSH alias"
        fi
        press_enter_to_continue
        ;;
      12)
        run_external_repository || true
        ;;
      q | Q)
        print_info "Goodbye!"
        return 0
        ;;
      *)
        print_error "Invalid option: $choice"
        press_enter_to_continue
        ;;
    esac
  done
}

# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ Entry Point                                                                  │
# └──────────────────────────────────────────────────────────────────────────────┘

# Main logic
check_root

if ! RAVNVM_REPO=$(normalize_repository_url "$RAVNVM_REPO"); then
    exit 2
fi

if [[ $# -eq 0 ]]; then
    clear || true
    print_ravnvm_banner
    if ! recover_environment; then
        print_info "RavnVM closed without starting a VM"
        exit 0
  fi
    run_interactive_menu
    exit 0
fi

persistent="false"
ref="master"

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --persist)
            persistent="true"
            shift
            ;;
        --repo)
            if [[ $# -lt 2 ]]; then
                print_error "--repo requires owner/name or an HTTPS .git URL"
                exit 2
      fi
            if ! RAVNVM_REPO=$(normalize_repository_url "$2"); then
                exit 2
      fi
            shift 2
            ;;
        --list)
            list_snapshots
            exit 0
            ;;
        --storage)
            show_storage_status
            exit 0
            ;;
        --clean)
            clean_cache
            exit 0
            ;;
        --install-deps)
            install_all_arch_dependencies
            exit 0
            ;;
        --check-deps)
            check_deps_only
            exit $?
            ;;
        --install-ssh-alias)
            install_ssh_alias
            exit 0
            ;;
        --ssh)
            connect_ssh
            exit 0
            ;;
        --help | -h)
            print_usage
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
        *)
            ref="$1"
            shift
            ;;
  esac
done

run_vm_command_direct() {
    run_vm_command "$ref" "$persistent"
}

run_vm_command_direct
