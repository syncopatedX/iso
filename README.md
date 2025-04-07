# Syncopated ISO Builder 🐧 (ArchLabs: Re-imagined)

[![GitLab](https://img.shields.io/badge/GitLab-SyncopatedX-orange.svg)](https://gitlab.com/syncopatedX)

## 🚀 Overview

This project builds a custom Arch Linux based Live/Rescue ISO named **Syncopated**. It is a continuation of the [ArchLabs](https://en.wikipedia.org/wiki/ArchLabs) project, tailored for research & development 🔬 and content generation ✍️.

The generated ISO (`syncopated*.iso`) serves as a versatile Linux Live/Rescue environment.

## ✨ Features

* **Arch Linux Base:** Leverages the flexibility and up-to-date nature of Arch Linux.
* **Multiple Kernel Options:** Supports building with standard, LTS, RT, and RT-LTS kernels 🧠 (configurable via the Ansible playbook).
* **CachyOS & Chaotic AUR Integration:** Utilizes the CachyOS and Chaotic AUR repositories for performance-optimized packages and extended software availability 🚀.
* **Boot Modes:** Supports various boot modes including BIOS (Syslinux MBR/El Torito) and UEFI (GRUB for ia32/x86_64). PXE boot options (NBD, NFS, HTTP) are also configured 🌐.
* **Installer & Bootstrap:** Includes a system installer (`/usr/local/bin/installer`) and a bootstrap script (`/usr/local/bin/bootstrap.sh`) for initial system setup ⚙️.
* **Custom Theming:** Includes the "oomox-soundbot" theme and custom backgrounds 🎨.
* **Accessibility:** Provides boot options with the speakup screen reader for both BIOS and UEFI 🗣️.
* **i3 Window Manager:** Uses i3 as the default window manager for a lightweight and efficient desktop experience 🖥️.

## 🛠️ Building the ISO

The primary method for building the ISO is using `mkarchiso`, which can be orchestrated via an Ansible playbook (`draft_build_playbook.yml`) or through the GitLab CI/CD pipeline.

**Prerequisites:**

* `archiso` package
* `base-devel` package group
* Ansible (for using the playbook)

**Build Process (using Ansible Playbook):**

1. **Ensure Prerequisites:** The playbook checks if `archiso` and `curl` are installed ✅.
2. **Configure Kernel:** Variables like `enable_lts_kernel`, `enable_rt_kernel`, or `enable_rt_lts_kernel` can be set to `true` to modify the build to use specific kernels. This modifies package lists and bootloader configurations ⚙️.
3. **Update Installer/Mirrors:** Can copy a local installer or fetch/update remote resources like the CachyOS and Chaotic AUR mirrorlists 🔄.
4. **Run `mkarchiso`:** Executes `mkarchiso -v .` in the project root directory to build the ISO 💿.

**Build Process (using GitLab CI/CD):**

The project includes a `.gitlab-ci.yml` file that automates the build process in the GitLab CI/CD environment. The pipeline:

1. Initializes and populates pacman keys
2. Adds the Chaotic AUR and CachyOS repositories
3. Updates the system packages
4. Builds the ISO using `mkarchiso`

## 🧪 Testing

A Ruby script (`run_test_vm.rb`) is provided to facilitate testing the generated ISO in a virtual environment using QEMU/KVM or virt-install.

**Usage:**

1. Ensure Ruby and necessary gems (`tty-prompt`, `shellwords`, `fileutils`) are installed 💎.
2. Ensure QEMU/KVM or Libvirt (`virt-install`) is installed and configured 🖥️.
3. Run the script: `ruby run_test_vm.rb`
4. The script will prompt for:
    * QEMU command type (`virt-install` or `qemu-system-x86_64`).
    * Number of vCPUs and Memory (MB).
    * Whether to create a new QCOW2 disk or use an existing one.
    * Selection of the ISO file and the QCOW2 drive file.
5. The script then executes the chosen command to start the VM ▶️.

## ⚙️ Post-Installation Bootstrap

A `bootstrap.sh` script is included in the `airootfs` (`/usr/local/bin/bootstrap.sh`). This script is designed to run on a newly installed system to:

* Install essential packages (like `openssh`, `base-devel`, `rsync`, `ansible`, etc.) based on the detected distribution (Arch, Fedora, Debian-based) 📦.
* Set up passwordless sudo 🔑.
* Configure Git username and email 👤.
* Optionally transfer SSH keys from another host ➡️.
* Clone a `SyncopatedOS` dotfiles repository (for further configuration) 📁.
* Execute an Ansible playbook (`playbooks/full.yml`) located within the cloned dotfiles repository ▶️.

## 📦 Custom Repository

The project includes a local repository for custom packages:

* **Location:** `/var/cache/pacman/syncopated`
* **Purpose:** Maintains and distributes custom packages alongside those from official repositories
* **Integration:** Can be included in the pacman.conf file of your ISO build:

```conf
[syncopated]
SigLevel = Optional TrustAll
Server = file:///var/cache/pacman/syncopated
```

**Adding Packages to the Repository:**

```bash
repo-add /var/cache/pacman/syncopated/syncopated.db.tar.gz ~/builds/my-package/*.pkg.tar.zst
```

**Updating the Package Database:**

```bash
sudo pacman -Sy
```

**Maintaining the Repository:**

To update a package:
1. Update the PKGBUILD (increment `pkgver` or `pkgrel`)
2. Rebuild the package
3. Add the new package to the repository
4. Remove the old package version if desired

## 🙏 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📜 License

This project is licensed under the GPL-2.0 license.
