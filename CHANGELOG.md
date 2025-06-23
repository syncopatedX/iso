# Changelog

## [unreleased]

### WIP

- Adding support for sway-wm

### Chore

- Renamed installer to installer.sh
- Updated default background image in nitrogen configuration
- Updated default wallpaper and repository URL

### Feat

- Updated packages for live session
- Added firewalld package
- Added NetworkManager startup to .xinitrc
- Conditionally started NetworkManager in live ISO sessions
- Disabled IPv6 for Wired Connection 1 and restarted NetworkManager in .xinitrc


## [1.1.5] - 2025-05-26

### Chore

- Set default Login Session to i3
- Added R option to getopts in build script
- Update VERSION_ID in /etc/os-release from 2025.04.07 to 2025.05.02
- Remove deprecated files and scripts
- Update build script to handle linux.preset in airootfs

### Feat

- Added nitrogen config files and ansible package
- Switched to Terminator and updated installer
- Add Realtime-LTS kernel option
- Improve system configuration and add realtime privileges
- Update package selection in installer
- Disable IPv6 by default
- Refactor run_test_vm.rb to use command pattern and improve user configuration
- Add .zprofile and fonts
- Copy /etc/sysctl.d to target during install_base
- Integrated Ansible for system configuration
- Added diagrams to README and included packages for Calamares and LVM

### Fix

- Corrected conditional logic for RT kernel configuration

## [1.1.0] - 2025-04-07

### Chore

- Remove obsolete file permission for automated script
- Remove GPL-2.0-only.txt license file
- Removed packages from WM_PKGS array in installer
- Removed microcode hook from mkinitcpio.conf
### Feat

- Update installer with package management improvements and package updates
- Add GPL-2.0-only license text file
- Refactor run_test_vm.rb to use relative paths and simplify QEMU command execution
- Add microcode hook and packages
- Update reflector arguments for mirrorlist generation
- Add .xinitrc and update installer packages
- Refactor installer and update packages list
- Configure Git LFS for image files
- Add .gitlab-ci.yml for building Syncopated OS ISO
- Add chaotic.cx mirrorlist and keyring to .gitlab-ci.yml
- Add pacman-key initialization and population to .gitlab-ci.yml
- Call install_cachyos_repos in install_check_bg and install_background
- Initial commit of PKGBUILD template and README
- Enhanced README with GitLab CI/CD, Chaotic AUR, custom repository details, and i3 WM

### Fix

- Copy additional dotfiles during base install
- Incorrect type. Expected "string | array".

### Ix

- Add --noconfirm flag to pacman -U commands in installer

### Todo

- Storage provider, testing

## [1.0.0] - 2025-04-07

### Chore

- Updated installer script

### Feat

- Update build script and package list for Syncopated
- Rename distribution from ArchLabs to Syncopated
- Switch to i3 window manager
- Update hostname and pacman configuration

