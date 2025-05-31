# Syncopated ISO

## ⚙️ System Design Overview: Syncopated ISO

Continuing the spirit and building upon the foundation of the **[ArchLabs Linux](https://en.wikipedia.org/wiki/ArchLabs)** project, the "syncopated iso" project is designed to build a custom, Arch Linux-based, bootable Live/Rescue ISO image. Its primary function is to provide a pre-configured environment suitable for system administration, recovery tasks, or as a platform for installing a customized Arch Linux system using its integrated installer script.

## About

This project aims to provide a lean-yet-functional Arch Linux environment, both as a bootable live medium and as an installable system, built using the [Archiso](https://wiki.archlinux.org/title/Archiso) framework. We are proud to continue the legacy of ArchLabs Linux, a project distinguished by the significant collaborative effort of its community. Its renowned clean and minimal design resulted in excellent performance, offering a superb foundation for a custom distribution like Syncopated ISO. We strive to maintain this minimalist aesthetic and user control, providing a well-configured starting point for users who appreciate a "do-it-yourself" approach. The installer script ([`installer.sh`](airootfs/usr/local/bin/installer.sh:0)) is also a direct descendant of this valuable ArchLabs work.

## Features

* **ArchLabs Heritage:** A spiritual successor to the defunct ArchLabs project.
* **Arch Linux Base:** Built upon the latest Arch Linux packages.
* **Archiso Framework:** Uses the official Archiso tools for building.
* **Broad Boot Support:** Boots on both legacy BIOS (Syslinux) and modern UEFI (GRUB) systems.
* **Custom Theming:** Includes themes like `oomox-soundbot`.
* **Pre-configured Tools:** Comes with Rofi, Ranger, Nitrogen, `sxhkd`, etc.
* **Installer:** Provides a custom installation script (`installer.sh`).
* **Security Aware:** Sets specific file permissions.

## Window Managers

Syncopated ISO aims to support:

1. **X11 Environment:** (Default/Current) A lightweight tiling window manager setup (e.g., i3/BSPWM/Openbox) configured via `.xinitrc`, `sxhkd`, Rofi, and Nitrogen.
2. **Sway (Wayland) Environment:** (Planned) A modern Wayland-based setup using [Sway](https://github.com/swaywm/sway/wiki), `waybar`, and Wayland-native tools. This option will be available in both the live environment and the installer once implemented.

## Building the ISO

### Prerequisites

* An Arch Linux system (or another Linux distribution with the necessary tools).
* `archiso` package installed.
* `git` (to clone the repository).
* Sufficient disk space (\~2-3 GB recommended for building).

### Steps

1. **Clone the Repository:**

    ```bash
    git clone https://gitlab.com/syncopatedX/iso.git # Or your current repo URL
    cd iso
    ```

2. **Prepare (Optional):**
      * Review `profiledef.sh` and adjust settings if needed.
      * Modify the package list (`packages.x86_64` - *Note: This file needs to be located/created*).
      * Update `airootfs/` with any custom configurations.

3. **Build the ISO:**

    ```bash
    sudo mkarchiso -v -w /tmp/archiso-work -o /tmp/archiso-out .
    ```

      * The `-w` flag specifies the working directory.
      * The `-o` flag specifies the output directory.
      * The resulting ISO file will be located in `/tmp/archiso-out`.

## Using the Live CD

1. **Create Bootable Media:** Write the generated `.iso` file to a USB drive using `dd` or a similar tool.

    ```bash
    # Example: Be VERY careful with of= - ensure it's your USB device!
    sudo dd bs=4M if=/tmp/archiso-out/syncopated-*.iso of=/dev/sdX status=progress oflag=sync
    ```

2. **Boot:** Boot your computer from the USB drive. You should see Syslinux (BIOS) or GRUB (UEFI) menus. Select the appropriate boot option.

3. **Login:**
      * *(TODO: Document the default username and password for the live environment).*

## Using the Installer

The ISO includes a custom installer script located at `/usr/local/bin/installer.sh`.

**⚠️ WARNING\! ⚠️**

* **Running this script WILL partition and format your hard drive.**
* **YOU WILL LOSE ALL DATA on the target drive.**
* **BACK UP ALL YOUR DATA before proceeding.**
* **Review the script's code before running it.**
* **Use at your own risk\!**

To run the installer (after booting the live CD):

```bash
sudo installer.sh
```

Follow the on-screen prompts carefully.

## Testing

A basic QEMU-based testing script, `run_test_vm.rb`, is included. It can be used to perform quick boot tests.

### Prerequisites

* Ruby
* QEMU/KVM

### Usage

*(TODO: Document how to use `run_test_vm.rb`, including any parameters it accepts).*

## Contributing

*(TODO: Add contribution guidelines, e.g., how to report bugs, submit merge requests, coding style).*

## License

*(TODO: Specify the project's license, e.g., MIT, GPLv3).*
