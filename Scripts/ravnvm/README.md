# RavnVM - Simplified VM Tool for RaVN Contributors

RavnVM is a streamlined development tool that guides RaVN setup in a virtual machine for testing different branches and commits.

- [RavnVM - Simplified VM Tool for RaVN Contributors](#ravnvm---simplified-vm-tool-for-ravn-contributors)
  - [Hardware Requirements](#hardware-requirements)
  - [Features](#features)
  - [Quick Start](#quick-start)
    - [Arch Linux](#arch-linux)
    - [NixOS](#nixos)
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
    - [Non-NixOS Hosts using Nix](#non-nixos-hosts-using-nix)
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

- **Zero Configuration**: Automatically downloads Arch Linux base image and sets up RaVN
- **Branch Testing**: Easily test any RaVN branch or commit hash
- **Smart Caching**: Creates cached snapshots for faster subsequent runs (uses XDG cache directory)
- **Optional Persistence**: Choose whether changes should be saved or discarded
- **OS Detection**: Automatically detects your OS and handles dependencies appropriately

## Quick Start

### Arch Linux

```bash
# Download and run (will auto-detect missing packages)
curl -L https://raw.githubusercontent.com/robert-flo/Valhalla/master/Scripts/ravnvm/ravnvm.sh -o ravnvm
chmod +x ravnvm
./ravnvm
```

### NixOS

```bash
# Using the Valhalla flake
nix run github:robert-flo/Valhalla

# Or if you have the repository cloned locally
nix run
```

## First-Time Setup

When you run a new branch/commit for the first time, ravnvm will:

1. **OS Detection**: Automatically detects your OS and checks dependencies
2. **Dependency Installation**: On Arch, reports when `ravnvm --install-deps` is required
3. **VM Setup**: Copies a setup script into the VM and shows the command to run
4. **RaVN Installation**: You'll need to:
   - Login as `arch` / `arch`
   - Run the displayed `./setup.sh <repository> <revision>` command
   - Wait for RaVN installation to complete
     - Hit enter for defaults
     - It will prompt for a password at the end, use `arch`
     - If you end up missing the password check, you can rerun the install script `./setup.sh`
   - Run `sudo poweroff` to shutdown and create the snapshot

**Subsequent runs are instant** - uses cached snapshot!


## Usage

### Interactive menu

Running `ravnvm` without arguments validates the host and opens the interactive
menu:

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
q  Exit
```

Revision actions offer ephemeral and persistent modes before starting the VM.
The custom action accepts a branch name or commit hash. All revision actions use
the configured GitHub repository inside the VM and never provision from the
host working tree.

Resource changes apply only to the current menu session. Storage reports show
the RavnVM cache, used filesystem space, and free space, with warnings at 80%
and 90% usage. Missing KVM remains a warning because QEMU can run without
hardware acceleration.

If required commands are missing, the normal menu remains unavailable and
RavnVM offers only dependency installation or exit. Use `q` for a normal exit;
`Ctrl-C` reports the interruption and cleans temporary VM state without removing
the cached base image.

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
```

### Make interface

The repository Makefile exposes the same RavnVM engine through development
targets:

```bash
# Run the current checkout revision, ephemerally or persistently
make dev-vm
make dev-vm-persist REF=dev

# Forward session resources and QEMU overrides
make dev-vm REF=feature/test VM_MEMORY=8G VM_CPUS=4
make dev-vm VM_EXTRA_ARGS=-nographic VM_QEMU_OVERRIDE=custom-qemu

# Inspect and administer RavnVM
make dev-vm-list
make dev-vm-clean
make dev-vm-setup
make dev-vm-size
make dev-vm-ssh

# Preview commands without starting or modifying a VM
make dev-vm REF=dev DRY_RUN=1
```

Run `make help` to discover all targets. The Make recipes delegate to
`Scripts/ravnvm/ravnvm.sh`; they do not implement a second VM lifecycle.

### Environment Variables

```bash
# Customize VM resources (defaults are 4G and 2 CPUs)
VM_MEMORY=8G VM_CPUS=4 ravnvm

# Set extra QEMU arguments
VM_EXTRA_ARGS="-display vnc=:1" ravnvm

# Override QEMU command entirely, provided $VM_DISK will be substituted with the actual disk image
VM_QEMU_OVERRIDE="qemu-system-x86_64 -m 4G -smp 2 -enable-kvm -drive file=\$VM_DISK,format=qcow2,if=virtio -device virtio-vga -display gtk" ravnvm
```

## VM Details

- **Login**: `arch` / `arch`
- **SSH Access**: `ssh arch@localhost -p 2222`
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
- **NixOS**: Run RavnVM through the flake so its runtime commands are provided by Nix.

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

### Non-NixOS Hosts using Nix

For non-NixOS hosts, use [nixGL](https://github.com/nix-community/nixGL) for better graphics support:

```bash
# Install nixGL first, then run RavnVM
nixGL nix run github:robert-flo/RaVN
```

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
