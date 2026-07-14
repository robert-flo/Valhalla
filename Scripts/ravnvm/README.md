# RavnVM - Simplified VM Tool for RaVN Contributors

RavnVM is a streamlined development tool that guides RaVN setup in a virtual machine for testing different branches and commits.

- [RavnVM - Simplified VM Tool for RaVN Contributors](#ravnvm---simplified-vm-tool-for-ravn-contributors)
  - [Hardware Requirements](#hardware-requirements)
  - [Features](#features)
  - [Quick Start](#quick-start)
  - [First-Time Setup](#first-time-setup)
  - [Usage](#usage)
    - [Interactive menu](#interactive-menu)
    - [Basic Commands](#basic-commands)
    - [Make interface](#make-interface)
    - [Environment Variables](#environment-variables)
  - [VM Details](#vm-details)
  - [Troubleshooting](#troubleshooting)
    - [KVM Not Available](#kvm-not-available)
    - [Missing Dependencies](#missing-dependencies)
    - [Clean Start](#clean-start)
  - [VM Host Guide](#vm-host-guide)
    - [Hardware Requirements (Detailed)](#hardware-requirements-detailed)
    - [AMD GPU + Any CPU ✅](#amd-gpu--any-cpu-)
    - [Intel CPU with iGPU ✅](#intel-cpu-with-igpu-)
    - [NVIDIA GPU + Any CPU ⚠️](#nvidia-gpu--any-cpu-️)
    - [Custom QEMU Configuration](#custom-qemu-configuration)
    - [Verification Steps](#verification-steps)
    - [Troubleshooting Hyprland in VM](#troubleshooting-hyprland-in-vm)

**Supported Host Operating Systems:** Arch Linux, NixOS

## Hardware Requirements

**CPU:** x86_64 with virtualization support (Intel VT-x or AMD-V, enabled in BIOS)
**Memory:** 4GB+ RAM (VM uses 4GB by default)
**GPU Compatibility:**

- ✅ **AMD GPU** - Excellent (HD 7000+ series, Mesa drivers)
- ✅ **Intel iGPU** - Excellent (HD 4000+ Ivy Bridge, Mesa drivers)
- ⚠️ **NVIDIA GPU** - May need tweaking (GTX 600+ series, proprietary drivers can cause issues)

**OpenGL:** 3.3+ support required for Hyprland
**Note:** Tested on AMD GPU + Intel CPU. Hyprland VM support is experimental.

## Features

- **Guided Setup**: Automatically downloads the Arch Linux base image and copies the RaVN setup script into the VM
- **Branch Testing**: Easily test any RaVN branch or commit hash
- **Smart Caching**: Creates cached snapshots for faster subsequent runs (uses XDG cache directory)
- **Optional Persistence**: Choose whether changes should be saved or discarded
- **OS Detection**: Automatically detects your OS and handles dependencies appropriately

## Quick Start

```bash
# Clone and run (will auto-detect missing packages)
git clone https://github.com/robert-flo/Valhalla.git
cd Valhalla
Scripts/ravnvm/ravnvm.sh
```

## First-Time Setup

When you run a new branch/commit for the first time, ravnvm will:

1. **OS Detection**: Automatically detects your OS and checks dependencies
2. **Dependency Installation**: On Arch, offers to install missing packages
3. **VM Setup**: Copies a setup script into the VM and shows the command to run
4. **RaVN Installation**: You'll need to:
   - Login as `arch` / `arch`
   - Run `chmod +x ./setup.sh && ./setup.sh`
   - Wait for RaVN installation to complete
     - Hit enter for defaults
     - It will prompt for a password at the end, use `arch`
     - If you end up missing the password check, you can rerun the install script `./setup.sh`
   - Run `sudo poweroff` to shutdown and create the snapshot

**Subsequent runs are instant** - uses cached snapshot!


## Usage

### Interactive menu

Running `ravnvm` without arguments validates the host first and opens the
interactive menu. The menu is the friendly interface for the same VM engine:

```text
1  Run master branch
2  Run dev branch
3  Run current branch
4  Run other branch or commit
5  Show VM storage usage
6  Clean VM cache
7  List VM snapshots
8  Configure RAM and CPU
9  Show RavnVM usage
10 Connect to VM via SSH
11 Install SSH alias
q  Exit
```

Options 1–4 open a second menu where you choose `Ephemeral` (discard changes),
`Persistent` (save changes), or `Back`. Option 4 accepts either a remote branch
name or a commit hash. RavnVM always clones or updates the RaVN repository from
GitHub inside the VM; it does not provision from local working-tree changes.

Option 8 changes RAM and CPU for the current process only. The defaults are
`VM_MEMORY=4G` and `VM_CPUS=2`. Option 9 displays the same usage information as
`ravnvm --help`, option 10 connects to the running VM on SSH port 2222, and
option 11 installs the optional `ssh ravnvm` host alias.

The menu validates the host environment first and shows the RavnVM cache size,
filesystem usage, free space, and a storage warning when usage reaches 80% or
90%. Missing KVM is reported as a warning because QEMU can still run without
hardware acceleration.

Use `q` to exit and `Ctrl-C` to abort the current operation. RavnVM reports the
interruption, preserves diagnostic output, and never removes the base image
during an abort. If required dependencies are missing, only dependency
installation and exit are offered until validation succeeds.

### Basic Commands

```bash
# Run master branch directly
ravnvm master

# Run specific branch or commit
ravnvm feature-branch
ravnvm abc123def

# Run with persistence (changes will be saved)
ravnvm --persist
ravnvm --persist dev-branch

# List cached snapshots
ravnvm --list

# Clean snapshots and temporary data while preserving the base image
ravnvm --clean

# Show cache and filesystem storage usage
ravnvm --storage

# Check dependencies
ravnvm --check-deps

# Install dependencies (Arch only)
ravnvm --install-deps

# Install the optional `ssh ravnvm` host alias
ravnvm --install-ssh-alias
```

### Make interface

The repository's `make/dev.mk` exposes RavnVM through development targets. This
is an alternative interaction surface over the same VM engine:

```bash
# Run the current branch, or choose a revision with REF
make dev-vm
make dev-vm REF=dev
make dev-vm REF=abc123def

# Run with persistent changes
make dev-vm-persist REF=dev

# Inspect and manage snapshots
make dev-vm-list
make dev-vm-clean

# Check dependencies and inspect VM disk usage
make dev-vm-setup
make dev-vm-storage
make dev-vm-size # Compatibility alias for dev-vm-storage
make dev-vm-ssh
make dev-vm-install-ssh-alias

# Run an external repository for a one-off test
make dev-vm-external REPO=robert-flo/Valhalla REF=master
make dev-vm-external REPO=https://github.com/robert-flo/Valhalla.git REF=dev

# Preview a target without launching or changing the VM
make dev-vm DRY_RUN=1 REF=dev
```

The Make integration source is `make/dev.mk`; it mirrors the interactive menu
for revision execution, persistence, snapshots, cleanup, storage, dependency
setup, resource defaults, and SSH access.

`make dev-vm` defaults `REF` to the active checkout branch. VM resource
variables and QEMU overrides can be passed through the make interface.
`dev-vm-external` requires `REPO` and defaults `REF` to `master`; it does not
change the default RaVN repository used by the regular targets.

### Environment Variables

```bash
# Customize VM resources (defaults are 4G and 2 CPUs)
VM_MEMORY=8G VM_CPUS=4 ravnvm

# Set extra QEMU arguments
VM_EXTRA_ARGS="-display vnc=:1" ravnvm

# Use another repository from the command line; owner/name is also accepted
RAVNVM_REPO=robert-flo/Valhalla ravnvm master
ravnvm --repo robert-flo/Valhalla master

# Override QEMU command entirely, provided $VM_DISK will be substituted with the actual disk image
VM_QEMU_OVERRIDE="qemu-system-x86_64 -m 4G -smp 2 -enable-kvm -drive file=\$VM_DISK,format=qcow2,if=virtio -device virtio-vga -display gtk" ravnvm
```

## VM Details

- **Login**: `arch` / `arch`
- **SSH Access**: `ssh arch@127.0.0.1 -p 2222` or `ravnvm --ssh`
- **SSH Alias**: run `ravnvm --install-ssh-alias` once, then use `ssh ravnvm`
- **Persistence**: Optional flag determines if changes are saved
- **Cache Directory**: Uses XDG Base Directory specification (`$XDG_CACHE_HOME/ravnvm/`)
- **Snapshots**: Stored in `$XDG_CACHE_HOME/ravnvm/snapshots/` (typically `~/.cache/ravnvm/snapshots/`)
- **Base Image**: Cached in `$XDG_CACHE_HOME/ravnvm/archbase.qcow2` (typically `~/.cache/ravnvm/archbase.qcow2`)

## Troubleshooting

### KVM Not Available

```bash
# Arch Linux
sudo usermod -a -G kvm $USER

# NixOS - add to configuration.nix
virtualisation.libvirtd.enable = true;
```

### Missing Dependencies

- **Arch**: Run `ravnvm --install-deps` when the dependency check reports missing commands.
- **NixOS**: Provide `qemu`, `curl`, `python3`, and `git` through `nix-shell` or the system configuration.

### Clean Start

```bash
ravnvm --clean  # Remove snapshots and temporary data; preserve archbase.qcow2
```

## VM Host Guide

RaVN uses Hyprland, which has specific requirements for VM environments. Hyprland VM support is limited - see [Hyprland - Running in a VM](https://wiki.hypr.land/Getting-Started/Installation/#running-in-a-vm) for official guidance.

> [!NOTE]
> I'm trying here to make RaVN easier to work with VM's. If you have any suggestions based on your hardware and experience, or find this documentation inaccurate, please let me know.

**Key Requirements:**

- VirtIO GPU support
- OpenGL 3.3+ acceleration
- VT-x/AMD-V virtualization support

### Hardware Requirements (Detailed)

**CPU:**

- Intel CPU with VT-x or AMD CPU with AMD-V
- Virtualization enabled in BIOS/UEFI

**GPU & OpenGL Support:**

- ✅ **AMD**: HD 7000+ series (Mesa drivers recommended)
- ✅ **Intel**: HD 4000+ (Ivy Bridge) or newer
- ⚠️ **NVIDIA**: GTX 600+ series (proprietary drivers may cause issues)
- **OpenGL 3.3+ support required**

### AMD GPU + Any CPU ✅

**Packages (Arch):** `qemu-desktop mesa`
**Packages (NixOS):** `qemu mesa`

**NixOS Configuration:**

```nix
{
  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [ amdvlk ];
  boot.kernelModules = [ "kvm-intel" ]; # or "kvm-amd" for AMD CPUs
  virtualisation.libvirtd.enable = true;
}
```

```bash
# Test OpenGL
glxinfo | grep "OpenGL renderer"

# Verify VirtIO support
modprobe virtio_gpu
lsmod | grep virtio

# Default QEMU args should work perfectly
ravnvm
```

### Intel CPU with iGPU ✅

**Packages (Arch):** `qemu-desktop mesa intel-media-driver`
**Packages (NixOS):** `qemu mesa intel-media-driver`

**NixOS Configuration:**

```nix
{
  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];
  boot.kernelModules = [ "kvm-intel" ];
  virtualisation.libvirtd.enable = true;
}
```

```bash
# Test OpenGL
glxinfo | grep "OpenGL renderer"

# Verify VirtIO support
modprobe virtio_gpu
lsmod | grep virtio

# Default QEMU args should work perfectly
ravnvm
```

### NVIDIA GPU + Any CPU ⚠️

Option 1: Proprietary Drivers (May have issues)

```bash
# Packages (Arch)
sudo pacman -S qemu-desktop nvidia nvidia-utils

# Packages (NixOS) - add to configuration.nix:
{
  hardware.graphics.enable = true;
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;
  hardware.nvidia.modesetting.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  boot.kernelModules = [ "kvm-intel" ]; # or "kvm-amd"
  virtualisation.libvirtd.enable = true;
}

# Test OpenGL
glxinfo | grep "OpenGL renderer"

# If graphics issues occur, disable GL acceleration
VM_EXTRA_ARGS="-device virtio-vga -display gtk,gl=off" ravnvm
```

Option 2: Nouveau Drivers

```bash
# Packages (Arch)
sudo pacman -S qemu-desktop mesa xf86-video-nouveau

# Packages (NixOS) - add to configuration.nix:
{
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nouveau" ];
  boot.kernelModules = [ "kvm-intel" ]; # or "kvm-amd"
  virtualisation.libvirtd.enable = true;
}

# Test OpenGL
glxinfo | grep "OpenGL renderer"

# Should work with default args
ravnvm
```

Option 3: Software Rendering (Fallback)

```bash
# Force software rendering
VM_EXTRA_ARGS="-device VGA -display gtk,gl=off" ravnvm
```

### Custom QEMU Configuration

The default configuration uses these optimized arguments for Hyprland:

```bash
# Current default (automatically applied)
-device virtio-vga-gl
-display gtk,gl=on,grab-on-hover=on
-enable-kvm
-cpu host
```

For complete control over QEMU arguments:

```bash
# Override entire QEMU command
VM_QEMU_OVERRIDE="qemu-system-x86_64 -m 4G -smp 2 -enable-kvm -cpu host -machine q35 -device intel-iommu -drive file=\$VM_DISK,format=qcow2,if=virtio -device virtio-vga-gl -display gtk,gl=on,grab-on-hover=on -usb -device usb-tablet -device ich9-intel-hda -device hda-output -vga none" ravnvm

# The script will substitute $VM_DISK with the appropriate disk image
```

### Verification Steps

```bash
# 1. Check CPU virtualization support
egrep -c '(vmx|svm)' /proc/cpuinfo    # Should return > 0

# 2. Check KVM modules
lsmod | grep kvm                       # Should show kvm and kvm_intel/kvm_amd

# 3. Check OpenGL support
glxinfo | grep "OpenGL"               # Should show your GPU and OpenGL 3.3+

# 4. Check dependencies and system info
ravnvm --check-deps

# 5. If issues occur, try software rendering
VM_EXTRA_ARGS="-device VGA -display gtk,gl=off" ravnvm
```

### Troubleshooting Hyprland in VM

If you encounter issues with Hyprland in the VM:

1. **Graphics Issues**: Try disabling GL acceleration

   ```bash
   VM_EXTRA_ARGS="-device virtio-vga -display gtk,gl=off" ravnvm
   ```

2. **Input Issues**: Ensure USB tablet is enabled (included in enhanced config)

3. **Audio Issues**: The enhanced config includes Intel HDA audio support

4. **Performance Issues**: Ensure KVM is enabled and working:

   ```bash
   # Check KVM access
   ls -la /dev/kvm
   # Should show your user has access (via kvm group)
   ```

**Note:** Hyprland VM support is experimental. For the best experience, consider using a bare metal installation for development.
