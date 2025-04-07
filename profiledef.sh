#!/usr/bin/env bash
# shellcheck disable=SC2034

# this is modified by the build script when using the LTS kernel
iso_name="syncopated"

iso_label="SL$(date +%Y%m)"
iso_publisher="Syncopated <https://gitlab.com/syncopatedX>"
iso_application="Linux Live/Rescue CD"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')

#bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')

# to build with grub instead of systemd-boot
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-ia32.grub.esp' 'uefi-x64.grub.esp' 'uefi-ia32.grub.eltorito' 'uefi-x64.grub.eltorito')

arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.local/bin/rofi_run"]="0:0:755"
  ["/root/.local/bin/reload-sxhkd.sh"]="0:0:755"
  ["/root/.config/rofi/scripts/launcher_main.sh"]="0:0:755"
  ["/root/.config/rofi/scripts/launcher_t1.sh"]="0:0:755"
  ["/root/.config/rofi/scripts/launcher_t4.sh"]="0:0:755"
  ["/etc/skel/.config/rofi/scripts/launcher_main.sh"]="0:0:755"
  ["/etc/skel/.config/rofi/scripts/launcher_t1.sh"]="0:0:755"
  ["/etc/skel/.config/rofi/scripts/launcher_t4.sh"]="0:0:755"
  ["/etc/skel/.config/ranger/scope.sh"]="0:0:755"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/installer"]="0:0:755"
  ["/usr/local/bin/bootstrap.sh"]="0:0:755"
  ["/usr/local/bin/reload-sxhkd.sh"]="0:0:755"
)
