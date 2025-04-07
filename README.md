# Syncopated ISO Builder 🐧 (ArchLabs: Re-imagined)

[![GitLab](https://img.shields.io/badge/GitLab-SyncopatedX-orange.svg)](https://gitlab.com/syncopatedX)

## 🚀 Overview

This project builds a custom Arch Linux based Live/Rescue ISO named **Syncopated**. It is a continuation of the [ArchLabs](https://en.wikipedia.org/wiki/ArchLabs) project, tailored for research & development 🔬 and content generation ✍️.

The generated ISO (`syncopated*.iso`) serves as a versatile Linux Live/Rescue environment  cứu hộ.

## ✨ Features

* **Arch Linux Base:** Leverages the flexibility and up-to-date nature of Arch Linux.
* **Multiple Kernel Options:** Supports building with standard, LTS, RT, and RT-LTS kernels 🧠 (configurable via the Ansible playbook).
* **CachyOS Integration:** Optionally utilizes the CachyOS repositories and mirrorlist for potentially performance-optimized packages 🚀.
* **Boot Modes:** Supports various boot modes including BIOS (Syslinux MBR/El Torito) and UEFI (GRUB for ia32/x86_64). PXE boot options (NBD, NFS, HTTP) are also configured 🌐.
* **Installer & Bootstrap:** Includes a system installer (`/usr/local/bin/installer`) and a bootstrap script (`/usr/local/bin/bootstrap.sh`) for initial system setup ⚙️.
* **Custom Theming:** Includes the "oomox-soundbot" theme 🎨.
* **Accessibility:** Provides boot options with the speakup screen reader for both BIOS and UEFI 🗣️.

## 🛠️ Building the ISO

The primary method for building the ISO appears to be using `mkarchiso` potentially orchestrated via an Ansible playbook (`draft_build_playbook.yml`).

**Prerequisites:**

* `archiso` package.
* Ansible (for using the playbook).

**Build Process (using Ansible Playbook):**

1. **Ensure Prerequisites:** The playbook checks if `archiso` and `curl` are installed ✅.
2. **Configure Kernel:** Variables like `enable_lts_kernel`, `enable_rt_kernel`, or `enable_rt_lts_kernel` can be set to `true` to modify the build to use specific kernels. This modifies package lists and bootloader configurations ⚙️.
3. **Update Installer/Mirrors:** Can copy a local installer or fetch/update remote resources like the CachyOS mirrorlist 🔄.
4. **Run `mkarchiso`:** Executes `mkarchiso -v .` in the project root directory to build the ISO 💿.

*(Note: Refer to `draft_build_playbook.yml` for detailed steps and variables.)*

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

A `bootstrap.sh` script is included in the `airootfs` (`/usr/local/bin/bootstrap.sh`). This script appears designed to run on a newly installed system to:

* Install essential packages (like `openssh`, `base-devel`, `rsync`, `ansible`, etc.) based on the detected distribution (Arch, Fedora, Debian-based) 📦.
* Set up passwordless sudo 🔑.
* Configure Git username and email 👤.
* Optionally transfer SSH keys from another host ➡️.
* Clone a `SyncopatedOS` dotfiles repository (presumably for further configuration) <0xF0><0x9F><0x93><0x81>.
* Execute an Ansible playbook (`playbooks/full.yml`) located within the cloned dotfiles repository ▶️.

## 🙏 Contributing

*(Information on contribution guidelines was not found in the provided files. Please add details here if applicable.)*

## 📜 License

*(License information was not found in the provided files. Please add details here.)*
