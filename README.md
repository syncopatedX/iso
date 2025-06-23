# Syncopated Linux ISO Builder

Build script for creating Syncopated Linux live ISO images based on Arch Linux.

## About

Syncopated Linux is a fork of the ArchLabs Linux distribution, reimagined as a specialized environment for audio production and creative workflows. While maintaining the minimalist philosophy and i3 window manager foundation of ArchLabs, Syncopated adds enhanced audio production capabilities, realtime kernel support, and a curated package selection tailored for musicians, sound engineers, and creative professionals.

## Prerequisites

Install required packages:
```bash
sudo pacman -S archiso curl
```

## Building the ISO

### Standard Build
```bash
sudo ./build.sh
```

### Kernel Variants
```bash
# LTS kernel
sudo ./build.sh -L

# Realtime-LTS kernel (for audio production)
sudo ./build.sh -R

# Show help
sudo ./build.sh -h
```

## Output

The built ISO will be created in the `out/` directory with the filename pattern `syncopated-<version>-<date>-x86_64.iso`.
