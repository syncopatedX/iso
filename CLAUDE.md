# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Syncopated Linux ISO Builder

This repository contains the build system for creating Syncopated Linux, an Arch Linux-based live ISO distribution. The project uses `archiso` to generate bootable ISO images with custom configurations, packages, and themes.

## Core Architecture

The ISO build process is based on the ArchISO framework:

- **`profiledef.sh`** - Main configuration file defining ISO metadata, boot modes, file permissions, and compression settings
- **`build.sh`** - Primary build script with kernel variant support (vanilla, LTS, Realtime-LTS)
- **`packages.x86_64`** - Complete package list for the live session (191 packages including i3-wm, development tools, networking utilities)
- **`airootfs/`** - Root filesystem overlay containing system configurations, dotfiles, and customizations
- **Boot configurations** - Multiple boot loader support (GRUB, syslinux, systemd-boot) in `efiboot/`, `grub/`, `syslinux/` directories

## Build Commands

### Primary Build Process
```bash
# Standard build (vanilla kernel)
./build.sh

# LTS kernel variant
./build.sh -L

# Realtime-LTS kernel variant (for audio production)
./build.sh -R

# Show help
./build.sh -h
```

### Build Dependencies
Ensure these packages are installed before building:
- `archiso` - ArchISO build tools
- `curl` - For downloading components

The build process:
1. Updates version information in `os-release`
2. Temporarily modifies configurations based on kernel variant
3. Runs `mkarchiso -m iso -v .` to create the ISO
4. Cleans up temporary files and reverts configuration changes
5. Reports build time

## Key Configuration Areas

### Package Management
- Live session includes comprehensive toolset: i3-wm, development tools (git, base-devel, cargo), networking (NetworkManager, iwd), system utilities
- Chaotic AUR integration via `chaotic-keyring` and `chaotic-mirrorlist`
- Custom pacman configuration in `pacman.conf`

### System Configuration
- **Network**: NetworkManager with systemd-resolved, IPv6 disabled by default
- **Audio**: PulseAudio with ALSA, realtime privileges configured
- **Display**: Xorg with i3 window manager, rofi launcher, nitrogen wallpaper manager
- **Security**: Firewalld, custom sysctl settings, realtime audio privileges

### Boot Configuration
- Multi-boot loader support (GRUB preferred over systemd-boot)
- UEFI and BIOS compatibility
- Custom GRUB theme and splash screens
- Speech synthesis support for accessibility

### File System Overlay (`airootfs/`)
- System-wide configurations in `/etc/`
- User skeleton files for default desktop environment
- Custom scripts and binaries in `/usr/local/bin/`
- Syncopated branding and themes

## Development Workflow

1. **Configuration Changes**: Modify files in `airootfs/` for system-level changes, or update `packages.x86_64` for package changes
2. **Testing**: Use the build script with different kernel variants to test configurations
3. **Version Management**: Git tags are automatically used for ISO versioning (`iso_version="$(git describe --tags)"`)
4. **Cleanup**: The build process automatically handles cleanup of temporary files

## Important Notes

- The build script temporarily modifies several configuration files during LTS/RT builds and reverts them afterward
- File permissions are strictly controlled via the `file_permissions` array in `profiledef.sh`
- The project targets both UEFI and BIOS systems with multiple boot loader options
- Network configuration prioritizes NetworkManager over systemd-networkd for desktop usability