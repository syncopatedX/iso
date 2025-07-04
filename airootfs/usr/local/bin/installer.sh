#!/bin/bash

# This program is free software, provided under the GNU GPL
# Written by Nathaniel Maia for Archlabs, works in most Arch based distros
# Some ideas and code reworked from other resources
# AIF, Calamares, and the Arch Wiki.. Credit where credit is due

FLAG_FILE="/root/.installer_has_run"

if [ -f "$FLAG_FILE" ]; then
    exit 0
fi



# shellcheck disable=2086,2046,2254,2164,2030,2031,2001
VER=2.30

# default values {

n=$(awk '/^NAME=/ {gsub(/^NAME=|"|'\''/, ""); print $1}' /etc/os-release 2>/dev/null)
DIST=${n:-Syncopated}
MNT=/mnt                                # installation root mountpoint if not set
SYS=Unknown                             # boot type, to be determined: UEFI/BIOS
FONT=ter-i16n                           # font used for the linux console
HOOKS=shutdown                          # additional mkinitcpio HOOKS
SEL=0                                   # currently selected main menu item
BTRFS=0                                 # is btrfs used, 1 = btrfs alone, 2 = btrfs + subvolume(s)
EXMNTS=''                               # extra partitions that were mounted, used to verify mountpoint and show user
USERCMD='systemctl enable sshd.service' # optional command(s) entered by the user to run in the chroot
NET_TYPE=networkmanager                 # network frontend type/package
ANS=/tmp/ans                            # dialog answer output file
BG=/tmp/bgout                           # output from background process
ERR=/tmp/errlog                         # stderr log used internally by errshow()
DBG=/tmp/debuglog                       # debug log file when passed -d

VIRT="$(systemd-detect-virt)"
MEM="$(awk '/MemTotal/ {print int($2 / 1024) "M"}' /proc/meminfo)"
LOCALES="$(awk '/UTF-8/ {gsub(/# .*|#/, ""); if ($1) {print $1 " - "}}' /etc/locale.gen)"
CMAPS="$(find /usr/share/kbd/keymaps -name '*.map.gz' | awk '{gsub(/\.map\.gz|.*\//, ""); print $1 " - "}' | sort)"

[[ $LINES ]] || LINES=$(tput lines)
[[ $COLUMNS ]] || COLUMNS=$(tput cols)

export DIALOGOPTS="--cr-wrap"

# package arrays built later from user selections
typeset -a SES_PKGS USER_PKGS

# }

# packages installed when any session is chosen {
typeset -a BASE_PKGS=(
	"acpi"
	"alsa-card-profiles"
	"alsa-firmware"
	"alsa-lib"
	"alsa-plugins"
	"alsa-tools"
	"alsa-utils"
	"ansible"
	"archiso"
	"aria2"
	"bash"
	"bat"
	"bc"
	"curl"
	"cargo"
	"ccache"
	"choose"
	"cmake"
	"docker-buildx"
	"docker-compose"
	"docker"
	"downgrade"
	"duf"
	"dust"
	"eza"
	"faac"
	"fd"
	"ffmpeg"
	"firewalld"
	"git"
	"gnome-themes-extra"
	"gping"
	"gst-libav"
	"gst-plugins-base"
	"gst-plugins-good"
	"gstreamer"
	"gtk3"
	"gum"
	"gvfs"
	"htop"
	"imagemagick"
	"inxi"
	"iotop"
	"jq"
	"kitty"
	"libmad"
	"libmatroska"
	"lnav"
	"mlocate"
	"most"
	"nodejs"
	"npm"
	"python-pip"
	"python-setuptools"
	"realtime-privileges"
	"rofi"
	"rsync"
	"rubygems"
	"sd"
	"sudo"
	"sxhkd"
	"terminator"
	"vorbis-tools"
	"wget"
	"xdg-user-dirs"
	"xorg-drivers"
	"xorg-xwayland"
	"xorg"
	"yadm"
	"zoxide"
) # }

# general packages for window managers to provide some basic functionality {
typeset -a WM_PKGS=(
	"adobe-source-han-sans-cn-fonts"
	"adobe-source-han-sans-jp-fonts"
	"adobe-source-han-sans-kr-fonts"
	"arandr"
	"awesome-terminal-fonts"
	"brightnessctl"
	"broot"
	"btop"
	"calcurse"
	"cosmic-icons-git"
	"dconf"
	"dex"
	"deepin-icon-theme"
	"dmenu"
	"dunst"
	"feh"
	"fontforge"
	"gedit-plugins"
	"gedit"
	"geoclue"
	"gitui"
	"gnu-free-fonts"
	"google-chrome"
	"gpick"
	"gsimplecal"
	"gtk-update-icon-cache"
	"gtksourceview3"
	"gtkspell3"
	"gucharmap"
	"gum"
	"gvfs-smb"
	"i7z"
	"imv"
	"input-remapper-git"
	"jupyter-nbconvert"
	"keepassxc"
	"lolcat"
	"lxappearance"
	"maim"
	"micro"
	"mpv"
	"nitrogen"
	"nvtop"
	"obsidian"
	"oh-my-zsh-git"
	"opendesktop-fonts"
	"openscad"
	"openslide"
	"picom"
	"polkit-gnome"
	"python-virtualenv"
	"qpdfview"
	"rtmidi"
	"terminator"
	"scrot"
	"seahorse"
	"sxiv"
	"texlive-fontsextra"
	"texlive-fontsrecommended"
	"timeshift"
	"tldr"
	"tree"
	"ttf-font-awesome"
	"ttf-hack-nerd"
	"ttf-icomoon-feather"
	"ttf-input"
	"ttf-jetbrains-mono"
	"ttf-liberation"
	"ttf-opensans"
	"ttf-ubuntu-font-family"
	"tuned"
	"vlc"
	"volumeicon"
	"webkit2gtk"
	"wmctrl"
	"wmfocus"
	"xclip"
	"xdg-user-dirs"
	"xdotool"
	"xsel"
	"xterm"
	"yad"
	"yt-dlp"
	"zenity"
	"zoxide"
	"zsh-autocomplete"
	"zsh-completions"
	"zsh-syntax-highlighting"
) # }

# packages installed to parity the .iso {
typeset -a ISO_PKGS=(
	"acpi"
	"alsa-firmware"
	"alsa-lib"
	"alsa-plugins"
	"alsa-utils"
	"amd-ucode"
	"arch-install-scripts"
	"archinstall"
	"aria2"
	"b43-firmware"
	"b43-fwcutter"
	"base-devel"
	"base"
	"bash"
	"bcachefs-tools"
	"bind"
	"bolt"
	"brltty"
	"broadcom-wl"
	"btrfs-progs"
	"cargo"
	"chaotic-keyring"
	"chaotic-mirrorlist"
	"clonezilla"
	"cloud-init"
	"cryptsetup"
	"curl"
	"darkhttpd"
	"ddrescue"
	"dhcpcd"
	"dialog"
	"diffutils"
	"dmenu"
	"dmidecode"
	"dmraid"
	"dnsmasq"
	"dosfstools"
	"dunst"
	"e2fsprogs"
	"edk2-shell"
	"efibootmgr"
	"espeakup"
	"ethtool"
	"exfatprogs"
	"eza"
	"f2fs-tools"
	"fatresize"
	"foot-terminfo"
	"fsarchiver"
	"firewalld"
	"gcc-libs"
	"git"
	"gpart"
	"gpm"
	"gptfdisk"
	"grml-zsh-config"
	"grub"
	"gsimplecal"
	"gum"
	"hdparm"
	"htop"
	"hyperv"
	"i3-wm"
	"i3status-rust"
	"intel-ucode"
	"iotop"
	"irssi"
	"iw"
	"iwd"
	"jfsutils"
	"kitty-terminfo"
	"kitty"
	"ldns"
	"less"
	"lftp"
	"libfido2"
	"libnotify"
	"libusb-compat"
	"linux-atm"
	"linux-firmware-marvell"
	"linux-firmware"
	"linux"
	"livecd-sounds"
	"lm_sensors"
	"lsscsi"
	"lvm2"
	"lynx"
	"man-db"
	"man-pages"
	"mc"
	"mdadm"
	"memtest86+-efi"
	"memtest86+"
	"mkinitcpio-archiso"
	"mkinitcpio-nfs-utils"
	"mkinitcpio"
	"modemmanager"
	"most"
	"mtools"
	"nano"
	"nbd"
	"ndisc6"
	"net-tools"
	"networkmanager"
	"nfs-utils"
	"nilfs-utils"
	"nitrogen"
	"nmap"
	"ntfs-3g"
	"nvme-cli"
	"oh-my-zsh-git"
	"open-iscsi"
	"open-vm-tools"
	"openconnect"
	"openpgp-card-tools"
	"openssh"
	"openvpn"
	"pacman-contrib"
	"pamixer"
	"partclone"
	"parted"
	"partimage"
	"paru"
	"pavucontrol"
	"pcsclite"
	"ppp"
	"pptpclient"
	"pulseaudio"
	"pv"
	"python-pip"
	"python-setuptools"
	"qemu-guest-agent"
	"ranger"
	"realtime-privileges"
	"refind"
	"reflector"
	"rofi"
	"rp-pppoe"
	"rsync"
	"rubygems"
	"rxvt-unicode-terminfo"
	"screen"
	"sdparm"
	"sequoia-sq"
	"sg3_utils"
	"smartmontools"
	"sof-firmware"
	"squashfs-tools"
	"sudo"
	"sxhkd"
	"syslinux"
	"systemd-resolvconf"
	"tcpdump"
	"terminus-font"
	"testdisk"
	"terminator"
	"tmux"
	"tpm2-tools"
	"tpm2-tss"
	"ttf-font-awesome"
	"ttf-hack-nerd"
	"ttf-icomoon-feather"
	"ttf-input"
	"ttf-jetbrains-mono"
	"ttf-liberation"
	"ttf-opensans"
	"ttf-ubuntu-font-family"	
	"udftools"
	"usb_modeswitch"
	"usbmuxd"
	"usbutils"
	"vim"
	"virtualbox-guest-utils-nox"
	"vpnc"
	"wireless_tools"
	"wireless-regdb"
	"wpa_supplicant"
	"wvdial"
	"xfsprogs"
	"xl2tpd"
	"xorg-server"
	"xorg-xinit"
	"xterm"
	"zsh"
) # }

# packages installed for each wm/de {
declare -A WM_EXT=(
	[bspwm]='bspwm jgmenu tint2 sxhkd'
	[fluxbox]='fluxbox jgmenu lxmenu-data'
	[i3 - wm]='i3status-rust sxhkd perl-anyevent-i3'
	[sway]='sway waybar rofi-wayland mako foot swaylock swayidle swaybg wl-clipboard'
	[openbox]='openbox obconf jgmenu tint2 conky lxmenu-data'
	[dwm]=''
) # }

# executable name for each wm/de used in ~/.xinitrc {
declare -A SESSIONS=(
	[dwm]='dwm'
	[i3 - wm]='i3'
	[sway]='sway'
	[bspwm]='bspwm'
	[fluxbox]='startfluxbox'
	[openbox]='openbox-session'
) # }

# packages installed for each login option {
declare -A LOGIN_PKGS=(
	[ly]='ly'
	[greetd]='greetd'
	[console]='xorg-xinit'
	[lightdm]='lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings accountsservice'
) # }

# extras installed for user selected packages {
# if a package requires additional packages that aren't already dependencies
# they can be added here e.g. [package]="extra"
declare -A PKG_EXT=(
	[bluez]='bluez-libs bluez-utils bluez-tools bluez-plugins bluez-hid2hci'
	[cairo - dock]='cairo-dock-plug-ins'
	[kdenlive]='qt5ct'
	[mpd]='mpc'
	[mupdf]='mupdf-tools'
	[noto - fonts]='noto-fonts-emoji'
	[pcmanfm]='tumbler'
	[qbittorrent]='qt5ct'
	[qutebrowser]='qt5ct'
	[thunar]='tumbler thunar-volman'
	[transmission - qt]='qt5ct'
	[vlc]='qt5ct'
	[zathura]='zathura-pdf-poppler'
) # }

# commands used to install each bootloader, however most get modified during runtime {
declare -A BCMDS=(
	[efistub]='efibootmgr -v -d /dev/sda -p 1 -c -l'
	[grub]='grub-install --recheck --force'
	[syslinux]='syslinux-install_update -i -a -m'
	[systemd - boot]='bootctl --path=/boot install'
) # }

# files offered for editing after install is complete {
declare -A EDIT_FILES=(
	[login]='' # login is populated once we know the username and shell
	[fstab]='/etc/fstab'
	[sudoers]='/etc/sudoers'
	[crypttab]='/etc/crypttab'
	[pacman]='/etc/pacman.conf'
	[console]='/etc/vconsole.conf'
	[mkinitcpio]='/etc/mkinitcpio.conf'
	[hostname]='/etc/hostname /etc/hosts'
	[bootloader]="/boot/loader/entries/${DIST,,}.conf" # ** based on bootloader
	[locale]='/etc/locale.conf /etc/default/locale'
	[keyboard]='/etc/X11/xorg.conf.d/00-keyboard.conf /etc/default/keyboard'
) # }

# mkfs command flags for filesystem formatting {
declare -A FS_CMD_FLAGS=(
	[btrfs]='-fq' [ext2]='-q' [ext3]='-q' [ext4]='-q' [f2fs]='-f' [jfs]='-q'
	[nilfs2]='-q' [ntfs]='-q' [reiserfs]='-q' [vfat]='-F32' [xfs]='-fq'
) # }

# mount options for each filesystem {
declare -A FS_OPTS=(
	[vfat]='' [ntfs]='' [ext2]='' [ext3]=''
	[jfs]='discard errors=continue errors=panic nointegrity'
	[reiserfs]='acl nolog notail replayonly user_xattr off'
	[ext4]='discard dealloc nofail noacl relatime noatime nobarrier nodelalloc'
	[xfs]='discard filestreams ikeep largeio noalign nobarrier norecovery noquota wsync'
	[nilfs2]='discard nobarrier errors=continue errors=panic order=relaxed order=strict norecovery'
	[f2fs]='discard fastboot flush_merge data_flush inline_xattr inline_data noinline_data inline_dentry no_heap noacl nobarrier norecovery noextent_cache disable_roll_forward disable_ext_identify'
	[btrfs]='autodefrag compress=zlib compress=lzo compress=no compress-force=zlib compress-force=lzo discard noacl noatime nodatasum nospace_cache recovery skip_balance space_cache ssd ssd_spread'
) # }

# dialog text variables {
# Basics (somewhat in order)
_keymap="\nSelect which keymap to use from the list below.\n\nThis will determine the installed system keymap once entering a graphical environment.\n\ndefault: us"
_vconsole="\nSelect the console keymap, the console is the tty shell you reach before starting a graphical environment (Xorg).\n\nIts keymap is separate from the one used by the graphical environments, though many do use the same such as 'us' English.\n\ndefault: us"
_prep="\nThis is the installer main menu, once a step is complete you will return here.\n\nOn successful completion of a step the cursor will advance to the next step.\nOn failure the cursor will be placed on the step required to advance (when possible).\n\nSteps beginning with an asterisk (*) are required.\n\nOnce all required steps are complete, selecting the last step will finalize the install."
_device="\nSelect a device to use from the list below.\n\nDevices (/dev) are the available drives on the system. /sda, /sdb, /sdc ..."
_mount="\nUse [Space] to toggle mount options from below, press [Enter] when done to confirm selection.\n\nNot selecting any and confirming will run an automatic mount."
_warn="\nIMPORTANT: Choose carefully when editing, formatting, and mounting partitions or your DATA MAY BE LOST.\n\nTo mount a partition without formatting it, select 'skip' when prompted to choose a file system during the mounting stage.\nThis can only be used for partitions that already contain a file system and cannot be the root (/) partition, it needs to be formatted before install.\n"
_part="\nFull device auto partitioning is available for beginners otherwise cfdisk is recommended.\n\n  - All systems will require a root partition (8G or greater).\n  - UEFI or BIOS using LUKS without LVM require a separate boot partition (100-512M)."
_btrfs="\nBtrfs can be used with or without creating subvolumes.\n\nAn initial subvolume will be created and mounted first,\nadditional subvolumes branching from this can be created after.\n\nCreate subvolumes?\n"
_uefi="\nSelect the EFI boot partition (/boot), required for UEFI boot.\n\nIt's usually the first partition on the device, 100-512M, and will be formatted as vfat/fat32 if not already."
_bios="\nDo you want to use a separate boot partition? (optional)\n\nIt's usually the first partition on the device, 100-512M, and will be formatted as ext3/4 if not already."
_biosluks="\nSelect the boot partition (/boot), required for LUKS.\n\nIt's usually the first partition on the device, 100-512M, and will be formatted as ext3/4 if not already."
_format="is already formatted correctly.\n\nFor a clean install, existing partitions should be formatted, however this removes ALL data (bootloaders) on the partition so choose carefully.\n\nDo you want to format the partition?\n"
_swapsize="\nEnter the size of the swapfile in megabytes (M) or gigabytes (G).\n\ne.g. 100M will create a 100 megabyte swapfile, while 10G will create a 10 gigabyte swapfile.\n\nFor ease of use and as an example it is filled in to match the size of your system memory (RAM).\n\nMust be greater than 1, contain only whole numbers, and end with either M or G."
_expart="\nYou can now choose any additional partitions you want mounted, you'll be asked for a mountpoint after.\n\nSelect 'done' to finish the mounting step and begin unpacking the base system in the background."
_exmnt="\nWhere do you want the partition mounted?\n\nEnsure the name begins with a slash (/).\nExamples include: /usr, /home, /var, etc."
_user="\nEnter a name and password for the new user account.\n\nThe name must not use capital letters, contain any periods (.), end with a hyphen (-), or include any colons (:)\n\nNOTE: Use [Up], [Down], or [Tab] to switch between fields, and [Enter] to accept."
_hostname="\nEnter a hostname for the new system.\n\nA hostname is used to identify systems on the network.\n\nIt's restricted to alphanumeric characters (a-z, A-Z, 0-9).\nIt can contain hyphens (-) BUT NOT at the beginning or end."
_locale="\nLocale determines the system language and currency formats.\n\nThe format for locale names is languagecode_COUNTRYCODE\n\ne.g. en_US is: English United States\n     en_GB is: English Great Britain"
_timez="\nSelect your timezone country or continent from the list below"
_timesubz="\nSelect your time zone city.\n\nTIP: Pressing a letter key repeatedly navigates between entries beginning with that letter."
_sessions="\nUse [Space] to toggle available sessions, use [Enter] to accept the selection and continue.\n\nA basic package set will be installed for compatibility and functionality."
_login="\nSelect which of your session choices to use for the initial login.\n\nYou can be change this later by editing your ~/.xinitrc"
_autologin="\nDo you want autologin enabled for USER?\n\nIf so the following two files will be created (disable autologin by removing them):\n\n - /home/USER/RC (run startx when logging in on tty1)\n - /etc/systemd/system/getty@tty1.service.d/autologin.conf (login USER without password)\n"
_packages="\nUse [Space] to toggle packages then press [Enter] to accept.\n\nPackages may be installed by your DE/WM (if any), or for the packages you select."
_usercmd="\nEnter command to be run in the newly installed system (chroot) below.\n\nAn example use case would be installing packages or editing files not offered in the menus.\n\nBecause the command will be run in a chroot not every command will function correctly, additionally the command will not be sanity checked, it's your system so exercise caution.\n\nMore than one command may be run using standard bash syntax.\n"
_edit="\nBefore exiting you can select configuration files to review/change.\n\nIf you need to make other changes with the drives still mounted, use Ctrl-z to pause the installer, when finished type 'fg' and [Enter] to resume the installer, if you want to avoid the automatic reboot using Ctrl-c will cleanly exit."

# LUKS
_luksmenu="\nA separate boot partition without encryption or logical volume management (LVM) is required (except BIOS systems using grub).\n\nBasic uses the default encryption settings, and is recommended for beginners. Advanced allows cypher and key size parameters to be entered manually."
_luksomenu="\nEnter a name and password for the encrypted device.\n\nIt is not necessary to prefix the name with /dev/mapper/, an example has been provided."
_lukskey="Once the specified flags have been amended, they will automatically be used with the 'cryptsetup -q luksFormat /dev/...' command.\n\nNOTE: Do not specify any additional flags such as -v (--verbose) or -y (--verify-passphrase)."

# LVM
_lvmmenu="\nLogical volume management (LVM) allows 'virtual' drives (volume groups) and partitions (logical volumes)\nto be created from existing device partitions. A volume group must be created first, then one or more logical volumes within it.\n\nLVM can also be used with a LUKS partition to create multiple logical volumes (e.g. root and home) within it."
_lvmvgname="\nEnter a name for the volume group (VG) being created from the partition(s) selected."
_lvmlvname="\nEnter a name for the logical volume (LV) being created.\n\nThis is similar to setting a label for a partition."
_lvmlvsize="\nEnter what size you want the logical volume (LV) to be in megabytes (M) or gigabytes (G).\n\ne.g. 100M will create a 100 megabyte volume, 10G will create a 10 gigabyte volume."
_lvmdelask="\nConfirm deletion of volume group(s) and logical volume(s).\n\nDeleting a volume group, will delete all logical volumes within it.\n"

# Errors
_errexpart="\nCannot mount partition due to a problem with the mountpoint.\n\nEnsure it begins with a slash (/) followed by at least one character.\n"
_errpart="\nYou need to create partition(s) first.\n\n\nBIOS systems require at least one partition (ROOT).\n\nUEFI systems require at least two (ROOT and EFI).\n"
_errchoice="\nIf you want to fix the issue yourself use Ctrl-z to pause the installer.\nFrom there you can do whatever is needed to resolve the error.\nOnce finished use the 'fg' command to resume the installer and select 'Continue'.\n"
_errvolname="\nInvalid name entered.\n\nThe volume name may be alpha-numeric, but may not contain spaces, start with a '/', or already be in use.\n"
_lukserr="\nA minimum of two partitions are required for LUKS encryption:\n\n 1. root (/) - standard or LVM.\n 2. boot (/boot) - standard (unless LVM on BIOS system).\n"
_lvmerr="\nThere are no available partitions to use for LVM, a minimum of one is required.\n\nIf LVM is already in use, deactivating it will allow the partition(s) to be used again.\n"
_lvmerrlvsize="\nInvalid value Entered.\n\nMust be a numeric value with 'M' (megabytes) or 'G' (gigabytes) at the end.\n\ne.g. 400M, 10G, 250G, etc...\n\nThe value may also not be equal to or greater than the remaining size of the volume group.\n"

# }

###############################################################################
# selection menus
# main is the entry point which calls functions including outside of its block
# once those functions finish they always return here with the
# exception of install_main(), it exits upon completion

main() {
	if [[ $NOMOUNT ]]; then
		((SEL < 8)) && ((SEL++))
		tput civis
		dialog --backtitle "$DIST - $SYS - v$VER" --title " Prepare " \
			--default-item $SEL --cancel-label 'Exit' --menu "$_prep" 0 0 0 \
			1 "* User and password" \
			2 "* System configuration" \
			3 "Select session(s)" \
			4 "Select packages" \
			5 "Run command" \
			6 "View configuration" \
			7 "* Complete install" 2>"$ANS"

		read -r SEL <"$ANS"
		case $SEL in
		1) prechecks 1 && { select_mkuser || ((SEL--)); } ;;
		2) prechecks 2 && { select_config || ((SEL--)); } ;;
		3) prechecks 3 && { select_sessions || ((SEL--)); } ;;
		4) prechecks 3 && { select_packages || ((SEL--)); } ;;
		5) prechecks 3 && select_usercmd ;;
		6) prechecks 3 && select_show ;;
		7) prechecks 3 && install_main ;;
		*) yesno "Exit" "\nUnmount partitions (if any) and exit the installer?\n" && die 0 ;;
		esac
	else
		((SEL < 13)) && ((SEL++))
		tput civis
		dialog --backtitle "$DIST - $SYS - v$VER" --title " Prepare " \
			--default-item $SEL --cancel-label 'Exit' --menu "$_prep" 0 0 0 \
			1 "Storage management" \
			2 "* Mount partitions" \
			3 "* User and password" \
			4 "* System configuration" \
			5 "Select session(s)" \
			6 "Select packages" \
			7 "Run command" \
			8 "View configuration" \
			9 "* Complete install" 2>"$ANS"

		read -r SEL <"$ANS"
		if [[ -z $WARN && $SEL == 2 ]]; then
			msg "Data Warning" "$_warn"
			WARN=true
		fi
		case $SEL in
		1) dev_menu || ((SEL--)) ;;
		2) mount_menu || SEL=0 ;;
		3) prechecks 1 && { select_mkuser || ((SEL--)); } ;;
		4) prechecks 2 && { select_config || ((SEL--)); } ;;
		5) prechecks 3 && { select_sessions || ((SEL--)); } ;;
		6) prechecks 3 && { select_packages || ((SEL--)); } ;;
		7) prechecks 3 && select_usercmd ;;
		8) prechecks 3 && select_show ;;
		9) prechecks 3 && install_main ;;
		*) yesno "Exit" "\nUnmount partitions (if any) and exit the installer?\n" && die 0 ;;
		esac
	fi
}

select_show() {
	local pkgs="${USER_PKGS[*]} ${SES_PKGS[*]}" fmtpkgs='' pkg=''
	[[ $INSTALL_WMS == *dwm* ]] && pkgs="dwm st dmenu $pkgs"
	pkgs="${pkgs//  / }"
	pkgs="${pkgs# }"

	# make a cleaner package list broken into lines around 60 characters
	pkgs="${pkgs// /\\n}"
	typeset -i count=0
	while read -re pkg; do
		if ((count < 55)); then
			fmtpkgs+="$pkg "
			((count += ${#pkg} + 1))
		else
			fmtpkgs+="\n              $pkg " # new line so we need to match indentation
			count=$((${#pkg} + 1))
		fi
	done < <(echo -e "$pkgs")

	msg "Show Configuration" "
---------- PARTITION CONFIGURATION ------------

  Root Part:      $ROOT - ${ROOTFS:-skipped}
  Boot Part:      ${BOOT:-none} - ${BOOTFS:-none}
  Boot Device:    ${BOOT_D:-none}
  Swap Part/File: ${SWAP:-none}
  Swap Size:      ${SWAP_S:-none}
  Extra Mounts:   ${EXMNTS:-none}
  Mkinit Hooks:   ${HOOKS:-none}

  LVM used:   ${LVM:-none}
  LUKS used:  ${LUKS:-none}

------------ SYSTEM CONFIGURATION -------------

  Locale:   ${LOCALE:-none}
  Keymap:   ${KEYMAP:-none}
  Hostname: ${NEWHOST:-none}
  Timezone: ${ZONE:-none}/${SUBZ:-none}

  Chroot cmd: ${USERCMD:-none}

------------ USER CONFIGURATION ---------------

  Username:      ${NEWUSER:-none}
  Login Shell:   ${NEWSHELL:-none}
  Login Session: ${LOGIN_WM:-i3}
  Autologin:     ${AUTOLOGIN:-none}
  Login Type:    ${LOGIN_TYPE:-none}

----------- PACKAGE CONFIGURATION -------------

  Kernel:     ${KERNEL:-none}
  Bootloader: ${BOOTLDR:-none}
  Packages:   ${fmtpkgs:-none}
"
}

select_login() {
	AUTOLOGIN=''

	dlg LOGIN_TYPE menu "Login" "\nSelect what kind of login management to use." \
		"console" "Console login with no graphical display manager" \
		"ly" "TUI display manager with an ncurses like interface" \
		"lightdm" "Lightweight display manager" || return 1

	case $LOGIN_TYPE in
	ly)
		EDIT_FILES[login]="/etc/ly/config.ini"
		;;
	lightdm)
		LIGHTDM_GREETER='gtk-greeter'
		EDIT_FILES[login]="/etc/lightdm/lightdm.conf /etc/lightdm/lightdm-gtk-greeter.conf"
		local txt="\nWith a deepin install you can choose to use their greeter for lightdm\n\nUse the deepin greeter?\n"
		[[ $INSTALL_WMS == *deepin* ]] && yesno "Greeter" "$txt" && LIGHTDM_GREETER="deepin-greeter"
		;;
	console)
		if (($(wc -w <<<"$INSTALL_WMS") > 1)); then
			dlg LOGIN_WM menu "Session" "$_login" $LOGIN_CHOICES || return 1
			LOGIN_WM="${SESSIONS[$LOGIN_WM]}"
		fi
		EDIT_FILES[login]="/home/$NEWUSER/.xinitrc /home/$NEWUSER/.xprofile"
		[[ -z $LOGIN_WM ]] && LOGIN_WM="${SESSIONS[${INSTALL_WMS%% *}]}"
		yesno "Autologin" "$(sed "s|USER|$NEWUSER|g; s|RC|$LOGINRC|g" <<<"$_autologin")" && AUTOLOGIN=true
		;;
	esac
	return 0
}

select_config() {
	typeset -i i=0
	CONFIG_DONE=''

	until [[ $CONFIG_DONE ]]; do
		case $i in
		0)
			dlg NEWSHELL menu "Shell" "\nChoose which shell to use." \
				zsh 'A very advanced and programmable command interpreter (shell) for UNIX' \
				bash 'The GNU Bourne Again shell, standard in many GNU/Linux distributions' \
				mksh 'The MirBSD Korn Shell - an enhanced version of the public domain ksh' || return 1

			;;
		1)
			dlg NEWHOST input "Hostname" "$_hostname" "${DIST,,}" limit || {
				i=0
				continue
			}
			;;
		2)
			dlg LOCALE menu "Locale" "$_locale" $LOCALES || {
				i=1
				continue
			}
			;;
		3)
			ZONE='' SUBZ=''
			until [[ $ZONE && $SUBZ ]]; do
				dlg ZONE menu "Timezone" "$_timez" \
					America - \
					Australia - \
					Asia - \
					Atlantic - \
					Africa - \
					Europe - \
					Indian - \
					Pacific - \
					Arctic - \
					Antarctica - || break

				dlg SUBZ menu "Timezone" "$_timesubz" $(awk '/'"$ZONE"'\// {
						gsub(/'"$ZONE"'\//, "")
						print $3 " - "
					}' /usr/share/zoneinfo/zone.tab | sort) || continue
			done
			[[ $ZONE && $SUBZ ]] || {
				i=2
				continue
			}
			;;
		4)
			dlg KERNEL menu "Kernel" "\nChoose which kernel to use." \
				linux 'Vanilla linux kernel and modules, with a few patches applied' \
				linux-lts 'Long-term support (LTS) linux kernel and modules' \
				linux-rt-lts 'Realtime (RT) Long-term support (LTS) linux kernel and modules' \
				linux-zen 'A effort of kernel hackers to provide the best kernel for everyday systems' \
				linux-hardened 'A security-focused linux kernel with hardening patches to mitigate exploits' || {
				i=3
				continue
			}
			;;
		5)
			if [[ $SYS == 'BIOS' ]]; then
				dlg BOOTLDR menu "BIOS Bootloader" "\nSelect which bootloader to use." \
					"grub" "The Grand Unified Bootloader, standard among many Linux distributions" \
					"syslinux" "A collection of boot loaders for booting drives, CDs, or over the network" || {
					i=4
					continue
				}
			else
				dlg BOOTLDR menu "UEFI Bootloader" "\nSelect which bootloader to use." \
					"systemd-boot" "A simple UEFI boot manager which executes configured EFI images" \
					"grub" "The Grand Unified Bootloader, standard among many Linux distributions" \
					"efistub" "Boot the kernel image directly (no chainloading support)" \
					"syslinux" "A collection of boot loaders for booting drives, CDs, or over the network (no chainloading support)" || {
					i=4
					continue
				}
			fi
			setup_${BOOTLDR}
			CONFIG_DONE=true
			;;
		esac
		((i++)) # progress through to the next choice
	done

	case $NEWSHELL in
	bash) LOGINRC='.bash_profile' ;;
	zsh) LOGINRC='.zprofile' ;;
	mksh) LOGINRC='.profile' ;;
	esac

	return 0
}

select_mkuser() {
	NEWUSER=''
	typeset -a ans
	local rootsec="--- Root password, if left empty the user password will be used ---"

	until [[ $NEWUSER ]]; do
		tput cnorm
		dialog --insecure --backtitle "$DIST - $SYS - v$VER" \
			--separator $'\n' --title " User " --mixedform "$_user" 0 0 0 \
			"Username:" 1 1 "${ans[0]}" 1 11 "$COLUMNS" 0 0 \
			"Password:" 2 1 '' 2 11 "$COLUMNS" 0 1 \
			"Password2:" 3 1 '' 3 12 "$COLUMNS" 0 1 \
			"$rootsec" 6 1 '' 6 68 "$COLUMNS" 0 2 \
			"Password:" 8 1 '' 8 11 "$COLUMNS" 0 1 \
			"Password2:" 9 1 '' 9 12 "$COLUMNS" 0 1 2>"$ANS" || return 1

		mapfile -t ans <"$ANS"

		# root passwords empty, so use the user passwords
		if [[ -z "${ans[4]}" && -z "${ans[5]}" ]]; then
			ans[4]="${ans[1]}"
			ans[5]="${ans[2]}"
		fi

		# make sure a username was entered and that the passwords match
		if [[ -z ${ans[0]} || ${ans[0]} =~ \ |\' || ${ans[0]} =~ [^a-z0-9] ]]; then
			msg "Invalid Username" "\nInvalid user name.\n\nPlease try again.\n"
			ans[0]=''
		elif [[ -z "${ans[1]}" || "${ans[1]}" != "${ans[2]}" ]]; then
			msg "Password Mismatch" "\nThe user passwords do not match.\n\nPlease try again.\n"
		elif [[ "${ans[4]}" != "${ans[5]}" ]]; then
			msg "Password Mismatch" "\nThe root passwords do not match.\n\nPlease try again.\n"
		else
			NEWUSER="${ans[0]}"
			USER_PASS="${ans[1]}"
			ROOT_PASS="${ans[4]}"
		fi
	done
	return 0
}

select_keymap() {
	if [[ ! -f /tmp/xkeys ]]; then
		dlg KEYMAP menu "Keyboard" "$_keymap" \
			us English af Afghani al Albanian am Armenian ara Arabic \
			at German au English az Azerbaijani ba Bosnian bd Bangla \
			be Belgian 'bg' Bulgarian br Portuguese bt Dzongkha bw Tswana \
			by Belarusian ca French 'cd' French ch German cm English \
			cn Chinese cz Czech de German dk Danish dz Berber \
			ee Estonian epo Esperanto es Spanish et Amharic 'fi' Finnish \
			fo Faroese fr French gb English ge Georgian gh English \
			gn French gr Greek hr Croatian hu Hungarian id Indonesian \
			ie Irish il Hebrew 'in' Indian iq Iraqi ir Persian \
			is Icelandic it Italian jp Japanese ke Swahili kg Kyrgyz \
			kh Khmer kr Korean kz Kazakh la Lao latam Spanish \
			lk Sinhala lt Lithuanian lv Latvian ma Arabic mao Maori \
			md Moldavian me Montenegrin mk Macedonian ml Bambara mm Burmese \
			mn Mongolian mt Maltese mv Dhivehi my Malay ng English \
			nl Dutch no Norwegian np Nepali ph Filipino pk Urdu \
			pl Polish pt Portuguese ro Romanian rs Serbian ru Russian \
			se Swedish si Slovenian sk Slovak sn Wolof sy Arabic \
			tg French th Thai tj Tajik tm Turkmen tr Turkish \
			tw Taiwanese tz Swahili ua Ukrainian uz Uzbek vn Vietnamese za English || return 1

		echo "$KEYMAP" >/tmp/xkeys
	else
		KEYMAP="$(</tmp/xkeys)"
		: "${KEYMAP='us'}"
	fi

	if [[ ! -f /tmp/ckeys ]]; then
		if [[ $CMAPS == *"$KEYMAP "* ]]; then
			CMAP="$KEYMAP"
		else
			dlg CMAP menu "Console Keymap" "$_vconsole" $CMAPS || return 1
		fi
		echo "$CMAP" >/tmp/ckeys
	else
		CMAP="$(</tmp/ckeys)"
		: "${CMAP='us'}"
	fi

	if [[ $TERM == 'linux' ]]; then
		loadkeys "$CMAP" >/dev/null 2>&1
	else
		setxkbmap "$KEYMAP" >/dev/null 2>&1
	fi

	return 0
}

select_usercmd() {
	dlg USERCMD input "Command" "$_usercmd" "$USERCMD" nolimit
}

select_mirrors() {
	codes=''
	MIRROR_URL=''
	typeset -g MIRROR_COUNTRY
	typeset c=""

	[[ $mirrorpid && ! -f /tmp/mcountry ]] && wait $mirrorpid
	REF_COUNTRIES="$(</tmp/mcountry)"
	[[ $REF_COUNTRIES ]] || REF_COUNTRIES="Argentina AR
	Australia AU
	Austria AT
	Azerbaijan AZ
	Bangladesh BD
	Belarus BY
	Belgium BE
	Bosnia and Herzegovina BA
	Brazil BR
	Bulgaria BG
	Cambodia KH
	Canada CA
	Chile CL
	China CN
	Colombia CO
	Croatia HR
	Czechia CZ
	Denmark DK
	Ecuador EC
	Estonia EE
	Finland FI
	France FR
	Georgia GE
	Germany DE
	Greece GR
	Hong Kong HK
	Hungary HU
	Iceland IS
	India IN
	Indonesia ID
	Iran IR
	Ireland IE
	Israel IL
	Italy IT
	Japan JP
	Kazakhstan KZ
	Kenya KE
	Latvia LV
	Lithuania LT
	Luxembourg LU
	Mexico MX
	Moldova MD
	Monaco MC
	Netherlands NL
	New Caledonia NC
	New Zealand NZ
	North Macedonia MK
	Norway NO
	Pakistan PK
	Paraguay PY
	Poland PL
	Portugal PT
	Romania RO
	Russia RU
	Réunion RE
	Serbia RS
	Singapore SG
	Slovakia SK
	Slovenia SI
	South Africa ZA
	South Korea KR
	Spain ES
	Sweden SE
	Switzerland CH
	Taiwan TW
	Thailand TH
	Turkey TR
	Ukraine UA
	United Kingdom GB
	United States US
	Uzbekistan UZ
	Vietnam VN"

	# build an associative array of country codes mapped to full names
	eval "typeset -A COUNTRIES=( $(awk '{
		if (NF > 3)
			printf("[%s]=\"%s %s %s\" ", $4, $1, $2, $3)
		else if (NF > 2)
			printf("[%s]=\"%s %s\" ", $3, $1, $2)
		else
			printf("[%s]=\"%s\" ", $2, $1)
		}' <<<"$REF_COUNTRIES"))"

	# build a string of available countries and codes with ofn calls for each
	avail="echo $(awk -v q="\"'" '{
			if (NF > 3) {
				printf("%s %s_%s_%s $(ofn %s \"$codes\") ", $4, $1, $2, $3, $4)
			} else if (NF > 2) {
				printf("%s %s_%s $(ofn %s \"$codes\") ", $3, $1, $2, $3)
			} else {
				printf("%s %s $(ofn %s \"$codes\") ", $2, $1, $2)
			}
		}' <<<"$REF_COUNTRIES")"

	while :; do
		# eval the ofn calls added to insert off/on for dialog checkbox
		cavail=$(eval $avail)
		c=""
		dlg codes check "Mirror Countries" "\nSelect which countries to use mirrors from.\n\nUse [Space] to toggle the selected item.\n\nNot choosing any will result in an automatic selection." $cavail || return 1
		for i in $codes; do
			i="${i//_/ }"
			c+="${COUNTRIES[$i]},"
		done
		yesno "Mirror Countries" "\nConfirm the following countries: $c\n" && break
	done

	MIRROR_COUNTRY="$c"

	# build a URL for mirror sorting without reflector
	for i in $codes; do
		if [[ $MIRROR_URL ]]; then
			MIRROR_URL+="&country=$i"
		else
			MIRROR_URL="https://www.archlinux.org/mirrorlist/?country=$i"
		fi
	done
	MIRROR_URL+='&use_mirror_status=on'

	return 0
}

select_sessions() {
	typeset -a pkgs
	LOGIN_CHOICES=''

	dlg INSTALL_WMS check "Sessions" "$_sessions\n" \
		openbox "A lightweight, powerful, and highly configurable stacking wm" "$(ofn openbox "$INSTALL_WMS")" \
		i3-wm "The improved dynamic tiling window manager" "$(ofn i3-wm "$INSTALL_WMS")" \
		sway "Dynamic tiling window manager for wayland" "$(ofn sway "$INSTALL_WMS")" \
		dwm "A dynamic WM for X that manages windows in tiled, floating, or monocle layouts" "$(ofn dwm "$INSTALL_WMS")" \
		bspwm "A tiling wm that represents windows as the leaves of a binary tree" "$(ofn bspwm "$INSTALL_WMS")" \
		fluxbox "A lightweight and highly-configurable window manager" "$(ofn fluxbox "$INSTALL_WMS")"

	[[ $INSTALL_WMS ]] || return 0

	if [[ $INSTALL_WMS =~ dwm ]]; then
		msg "DWM Install" "\nThe following programs be installed using\n\n  \`git clone .. && make install\`\n\nfrom /home/$NEWUSER/suckless\n\n  - dwm\n  - dmenu\n  - st\n"
	fi
	for i in ${INSTALL_WMS/dwm/}; do
		pkgs+=("$i")
	done

	for i in $INSTALL_WMS; do
		LOGIN_CHOICES+="$i - "
		if [[ $i =~ (plasma|deepin) ]]; then
			local pretxt="\nThere are some extra packages available for $i that can be installed:"
			local txt="These are larger package groups containing applications that are a part of $i"
			txt+=" but are not included in the $i package group."
			yesno "${i^} Extra" "$pretxt ${WM_EXT[$i]}\n\n$txt\n\nWould you like to install them?\n" || continue
		fi
		if [[ ${WM_EXT[$i]} ]]; then
			for j in ${WM_EXT[$i]}; do
				pkgs+=("$j")
			done
		fi
	done

	select_login || return 1

	for pkg in "${pkgs[@]}"; do [[ ${SES_PKGS[*]} != *"$pkg"* ]] && SES_PKGS+=("$pkg"); done

	{ [[ $INSTALL_WMS ]] && echo "$INSTALL_WMS" >/tmp/wmlist; } || rm -f /tmp/wmlist

	return 0
}

select_packages() {
	dlg UPKGS check " Packages " "$_packages" \
		base-devel "A group of packages required for AUR" "$(ofn base-devel "${USER_PKGS[*]}")" \
		blueman "GUI bluetooth device manager" "$(ofn blueman "${USER_PKGS[*]}")" \
		bluez "Simple CLI based bluetooth support" "$(ofn bluez "${USER_PKGS[*]}")" \
		code "An open-source text editor developed by GitHub" "$(ofn code "${USER_PKGS[*]}")" \
		code-marketplace "An open-source text editor developed by GitHub" "$(ofn code-marketplace "${USER_PKGS[*]}")" \
		firefox "An open-source web browser" "$(ofn firefox "${USER_PKGS[*]}")" \
		gimp "GNU Image Manipulation Program" "$(ofn gimp "${USER_PKGS[*]}")" \
		git "The fast distributed version control system" "$(ofn git "${USER_PKGS[*]}")" \
		gparted "A GUI frontend for creating and manipulating partition tables" "$(ofn gparted "${USER_PKGS[*]}")" \
		gpick "Advanced color picker using GTK+ toolkit" "$(ofn gpick "${USER_PKGS[*]}")" \
		htop "View current processes and monitor system state" "$(ofn htop "${USER_PKGS[*]}")" \
		kdenlive "A popular non-linear video editor for Linux" "$(ofn kdenlive "${USER_PKGS[*]}")" \
		mpv "A media player based on mplayer" "$(ofn mpv "${USER_PKGS[*]}")" \
		mupdf "Lightweight PDF and XPS viewer" "$(ofn mupdf "${USER_PKGS[*]}")" \
		nano "Pico editor clone with enhancements" "$(ofn nano "${USER_PKGS[*]}")" \
		nautilus "The default file manager for Gnome" "$(ofn nautilus "${USER_PKGS[*]}")" \
		neovim "A fork of Vim aiming to improve user experience, plugins, and GUIs." "$(ofn neovim "${USER_PKGS[*]}")" \
		nmap "Utility for network discovery and security auditing" "$(ofn nmap "${USER_PKGS[*]}")" \
		noto-fonts "Google Noto fonts" "$(ofn noto-fonts "${USER_PKGS[*]}")" \
		noto-fonts-cjk "Google Noto CJK fonts (Chinese, Japanese, Korean)" "$(ofn noto-fonts-cjk "${USER_PKGS[*]}")" \
		ntfs-3g "NTFS file system driver and utilities" "$(ofn ntfs-3g "${USER_PKGS[*]}")" \
		obs-studio "Free opensource streaming/recording software" "$(ofn obs-studio "${USER_PKGS[*]}")" \
		obsidian "A notebook app" "$(ofn obsidian "${USER_PKGS[*]}")" \
		ocenaudio "A program that lets you manipulate digital audio waveforms" "$(ofn ocenaudio "${USER_PKGS[*]}")" \
		openshot "An open-source, non-linear video editor for Linux" "$(ofn openshot "${USER_PKGS[*]}")" \
		playerctl "Media player controller for spotify, vlc, audacious, bmp, xmms2, and others." "$(ofn playerctl "${USER_PKGS[*]}")" \
		qbittorrent "An advanced bittorrent client" "$(ofn qbittorrent "${USER_PKGS[*]}")" \
		qpdfview "A GNOME web browser based on the WebKit rendering engine" "$(ofn qpdfview "${USER_PKGS[*]}")" \
		qt5ct "GUI for managing Qt based application themes, icons, and fonts" "$(ofn qt5ct "${USER_PKGS[*]}")" \
		qutebrowser "A keyboard-focused vim-like web browser based on Python and PyQt5" "$(ofn qutebrowser "${USER_PKGS[*]}")" \
		ranger "A simple vim-like file manager" "$(ofn ranger "${USER_PKGS[*]}")" \
		rxvt-unicode "A unicode enabled rxvt-clone terminal emulator" "$(ofn rxvt-unicode "${USER_PKGS[*]}")" \
		simplescreenrecorder "A feature-rich screen recorder" "$(ofn simplescreenrecorder "${USER_PKGS[*]}")" \
		terminator "Terminal emulator that supports tabs and grids" "$(ofn terminator "${USER_PKGS[*]}")" \
		thunar "A modern file manager for the Xfce Desktop Environment" "$(ofn thunar "${USER_PKGS[*]}")" \
		tilda "A GTK based drop down terminal for Linux and Unix" "$(ofn tilda "${USER_PKGS[*]}")" \
		tilix "A tiling terminal emulator for Linux using GTK+ 3" "$(ofn tilix "${USER_PKGS[*]}")" \
		ttf-anonymous-pro "A family fixed-width fonts designed with code in mind" "$(ofn ttf-anonymous-pro "${USER_PKGS[*]}")" \
		ttf-fira-code "Monospaced font with programming ligatures" "$(ofn ttf-fira-code "${USER_PKGS[*]}")" \
		ttf-font-awesome "Iconic font designed for Bootstrap" "$(ofn ttf-font-awesome "${USER_PKGS[*]}")" \
		ttf-hack "A hand groomed typeface based on Bitstream Vera Mono" "$(ofn ttf-hack "${USER_PKGS[*]}")" \
		unrar "The RAR compression program" "$(ofn unrar "${USER_PKGS[*]}")" \
		unzip "The RAR compression program" "$(ofn unzip "${USER_PKGS[*]}")" \
		vlc "A free and open source cross-platform multimedia player" "$(ofn vlc "${USER_PKGS[*]}")" \
		wget "Network utility to retrieve files from the Web" "$(ofn wget "${USER_PKGS[*]}")" \
		xapps "Common library for X-Apps project" "$(ofn xapps "${USER_PKGS[*]}")" \
		xarchiver "A GTK+ frontend to various command line archivers" "$(ofn xarchiver "${USER_PKGS[*]}")" \
		x42-plugins "Professional audio processing units available as LV2-plugin and JACK-application" "$(ofn x42-plugins "${USER_PKGS[*]}")"

	if [[ $UPKGS ]]; then # add any needed PKG_EXT to the list
		for i in $UPKGS; do
			[[ ${USER_PKGS[*]} != *"$i"* ]] && USER_PKGS+=("$i")
			if [[ ${PKG_EXT[$i]} ]]; then
				for j in ${PKG_EXT[$i]}; do
					[[ ${USER_PKGS[*]} != *"$j"* ]] && USER_PKGS+=("$j")
				done
			fi
		done
	fi

	return 0
}

###############################################################################
# device management menus
# acts as an in-between function to avoid cluttering the main menu
# also called when mounting but not enough partitions are present

dev_menu() {
	local txt="$1"
	local choice=''
	local back="Return to the main menu"
	[[ $txt ]] && back="Return to mounting"

	while :; do
		dlg choice menu "Device Management" \
			"\nHere you can perform some operations to modify system storage devices.\nSelect an option from the list below to see more.\n$txt" \
			'view' 'View the device tree output from lsblk' \
			'part' 'Modify the partition layout of a device' \
			'luks' 'Setup LUKS encryption on a partition or LVM' \
			'lvm' 'Setup logical volume management on partition(s)' \
			'back' "$back" || return 0

		if [[ -z $WARN && $choice != 'view' ]]; then
			if [[ -z $LVMWARN && $choice == 'lvm' ]]; then
				msg "LVM Warning" "\nIMPORTANT: Choose carefully when setting up LVM, the partitions chosen will be formatted and your DATA WILL BE LOST.\n\nLogical volumes created will need to be formatted before install.\n"
				LVMWARN=true
			else
				msg "Data Warning" "$_warn"
				WARN=true
			fi
		fi
		case "$choice" in
		'view') part_show ;;
		'part') part_menu && [[ "$AUTO_ROOT" ]] && return 0 ;;
		'luks') luks_menu || return 1 ;;
		'lvm') lvm_menu || return 1 ;;
		*) return 0 ;;
		esac
	done
	return 0
}

###############################################################################
# partitioning menu
# non-essential partitioning helpers called by the user when using the optional
# partition menu and selecting a device to edit

part_menu() {
	local device choice devhash

	is_bg_install || return 0
	devhash="$(lsblk -f | base64)"
	umount_dir "$MNT"
	part_device || return 1
	device="$DEVICE"

	while :; do
		choice=""
		dlg choice menu 'Modify Partitions' "$_part\n\n$(lsblk -no NAME,MODEL,SIZE,FSTYPE,LABEL "$device")" \
			'auto' 'Whole device automatic partitioning' \
			'cfdisk' 'Curses based variant of fdisk' \
			'cgdisk' 'Curses based variant of gdisk' \
			'parted' 'GNU partition editor' $([[ "$DISPLAY" ]] && hash gparted >/dev/null 2>&1 && printf \
				'gparted -') \
			'fdisk' 'Dialog-driven creation and manipulation of partitions' \
			'gdisk' 'A text-mode partitioning tool that works on GUID Partition Table (GPT) disks' \
			'back' 'Return to the device management menu' || return 0

		if [[ -z $choice || $choice == 'back' ]]; then
			return 0
		elif [[ $choice == 'auto' ]]; then
			local root_size txt label boot_fs boot_type
			root_size=$(lsblk -lno SIZE "$device" | awk 'NR == 1 {
				if ($1 ~ "G") {
					sub(/G/, "")
					print ($1 * 1000 - 512) / 1000 "G"
				} else {
					sub(/M/, "")
					print ($1 - 512) "M"
				}}')
			txt="\nWARNING: ALL data on $device will be destroyed and the following partitions will be created\n\n- "
			if [[ $SYS == 'BIOS' ]]; then
				label="msdos" boot_fs="ext4" boot_type="primary"
				txt+="$boot_fs boot partition with the boot flag enabled (512M)\n- "
			else
				label="gpt" boot_fs="fat32" boot_type="ESP"
				txt+="$boot_fs efi boot partition (512M)\n- "
			fi
			txt+="ext4 partition using all remaining space ($root_size)\n\nDo you want to continue?\n"
			yesno "Auto Partition" "$txt" && part_auto "$device" "$label" "$boot_fs" "$root_size" "$boot_type"
		else
			clear
			tput cnorm
			$choice "$device"
		fi
		if [[ $devhash != "$(lsblk -f | base64)" ]]; then
			msg "Probing Partitions" "\nInforming kernel of partition changes using partprobe\n" 0
			partprobe >/dev/null 2>&1
			[[ $choice == 'auto' ]] && return
		fi
	done
}

part_show() {
	msg "Device Tree" "\n\n$(
		lsblk -no NAME,MODEL,SIZE,TYPE,FSTYPE,MOUNTPOINT |
			awk '/disk|part|lvm|crypt/ && !'"/${IGNORE_DEV:-NONEXX}/"'{sub(/part|disk|crypt|lvm/, ""); print}'
	)\n\n"
}

part_auto() {
	local device="$1" label="$2" boot_fs="$3" size="$4" boot_type="$5" dev_info=""

	msg "Auto Partition" "\nRemoving partitions on $device and setting label to $label\n" 1

	dev_info="$(parted -s "$device" print 2>/dev/null)"

	swapoff -a
	while read -r PART; do
		[[ $PART ]] || continue
		parted -s "$device" rm "$PART" >/dev/null 2>"$ERR"
		errshow 0 "parted -s '$device' rm '$PART'" || return 1
	done <<<"$(awk '/^ [1-9][0-9]?/ {print $1}' <<<"$dev_info" | sort -r)"

	if [[ $(awk '/Table:/ {print $3}' <<<"$dev_info") != "$label" ]]; then
		parted -s "$device" mklabel "$label" >/dev/null 2>"$ERR"
		errshow 0 "parted -s '$device' mklabel '$label'" || return 1
	fi

	msg "Auto Partition" "\nCreating a 512M $boot_fs boot partition.\n" 1
	parted -s "$device" mkpart "$boot_type" "$boot_fs" 1MiB 513MiB >/dev/null 2>"$ERR"
	errshow 0 "parted -s '$device' mkpart '$boot_type' '$boot_fs' 1MiB 513MiB" || return 1

	sleep 0.5
	BOOT_D="$device"
	AUTO_BOOT=$(lsblk -lno NAME,TYPE "$device" | grep 'part' | sort | awk '{print "/dev/" $1}')

	if [[ $SYS == "BIOS" ]]; then
		mkfs.ext4 -q "$AUTO_BOOT" >/dev/null 2>"$ERR"
		errshow 0 "mkfs.ext4 -q '$AUTO_BOOT'" || return 1
	else
		mkfs.vfat -F32 "$AUTO_BOOT" >/dev/null 2>"$ERR"
		errshow 0 "mkfs.vfat -F32 '$AUTO_BOOT'" || return 1
	fi

	sleep 0.5
	msg "Auto Partition" "\nCreating a $size ext4 root partition.\n" 0
	if [[ $SYS == "BIOS" ]]; then
		parted -s "$device" mkpart primary ext4 513MiB 100% >/dev/null 2>"$ERR"
		errshow 0 "parted -s '$device' mkpart primary ext4 513MiB 100%" || return 1
	else
		parted -s "$device" mkpart "$DIST" ext4 513MiB 100% >/dev/null 2>"$ERR"
		errshow 0 "parted -s '$device' mkpart '$DIST' ext4 513MiB 100%" || return 1
	fi

	sleep 0.5
	AUTO_ROOT="$(lsblk -lno NAME,TYPE "$device" | grep 'part' | sort | awk 'NR==2 {print "/dev/" $1}')"
	mkfs.ext4 -q "$AUTO_ROOT" >/dev/null 2>"$ERR"
	errshow 0 "mkfs.ext4 -q '$AUTO_ROOT'" || return 1
	sleep 0.5
	msg "Auto Partition" "\nProcess complete.\n\n$(lsblk -o NAME,MODEL,SIZE,TYPE,FSTYPE "$device")\n"
}

###############################################################################
# partition management functions
# these are helpers used by other functions to do essential setup/teardown

part_find() {
	local regexp="$1" err=''

	PARTS="$(part_pretty "" "$regexp")"
	PART_COUNT=$(wc -l <<<"$PARTS")

	case "$regexp" in
	'part|lvm|crypt')
		[[ $PART_COUNT -lt 1 || ($SYS == 'UEFI' && $PART_COUNT -lt 2) ]] && err="$_errpart"
		;;
	'part|crypt')
		((PART_COUNT < 1)) && err="$_lvmerr"
		;;
	'part|lvm')
		((PART_COUNT < 2)) && err="$_lukserr"
		;;
	esac

	if [[ $err ]]; then
		msg "Not Enough Partitions" "$err" 0
		return 1
	fi
	return 0
}

part_swap() {
	local swp="$1"
	local size=0

	if [[ $swp == "$MNT/swapfile" && $SWAP_S ]]; then
		msg "Swap Setup" "\nCreating $SWAP_S swapfile at /swapfile\n\nThis can take a while.\n" 1
		case "${SWAP_S: -1}" in
		G) size=$((${SWAP_S:0:-1} * 1024)) ;;
		M) size=${SWAP_S:0:-1} ;;
		esac
		dd if=/dev/zero of="$swp" bs=1M count=$size 2>"$ERR"
		errshow 0 "dd if=/dev/zero of='$swp' bs=1M count=$size"
		chmod 600 "$swp" 2>"$ERR"
		errshow 0 "chmod 600 '$swp'"
	else
		msg "Swap Setup" "\nActivating swap partition $SWAP\n" 1
	fi
	mkswap "$swp" >/dev/null 2>"$ERR"
	errshow 0 "mkswap '$swp' > /dev/null"
	swapon "$swp" >/dev/null 2>"$ERR"
	errshow 0 "swapon '$swp' > /dev/null"
	return 0
}

part_mount() {
	local part="$1"
	local mntp="${MNT}$2"
	local fs
	fs="$(lsblk -lno FSTYPE "$part")"

	mkdir -p "$mntp"

	# skipped formatting on existing btrfs partition?
	if [[ $fs == 'btrfs' && $BTRFS -eq 0 ]] && yesno "Btrfs Subvolume Mount" "\nDo you have a subvolume on $part that should be mounted at $mntp?\n"; then
		btrfs_name "\nEnter the name of the subvolume on $part to be mounted at $mntp.\n\ne.g. mount -o subvol=YOUR_SUBVOL $part $mntp\n" || return 1
		btrfs_mount "$part" "$mntp" "$SUBVOL" || return 1
	else
		if [[ $BTRFS -ne 2 && $fs && ${FS_OPTS[$fs]} && $part != "$BOOT" && $part != "$AUTO_ROOT" ]] && mount_opts "$part" "$fs"; then
			mount -o $MNT_OPTS "$part" "$mntp" >/dev/null 2>"$ERR"
			errshow 0 "mount -o $MNT_OPTS $part $mntp" || return 1
		else
			MNT_OPTS=''
			mount "$part" "$mntp" >/dev/null 2>"$ERR"
			errshow 0 "mount $part $mntp" || return 1
		fi
		((BTRFS != 2)) && msg "Mount Complete" "\nMounted $part at $mntp\n" 1
	fi
	part_countdec "$part"
	part_cryptlv "$part"
	return 0
}

part_pretty() {
	local part="$1"   # valid block device partition or empty string for all
	local regexp="$2" # awk search regex for partition type or empty string for all
	local s dev size isize model

	# invalid block device passed in
	[[ $part && ! -b $part ]] && return

	# full search when not given a regex
	[[ $regexp == "" ]] && regexp="part|crypt|lvm"

	# string of partitions >= 80M
	# format: /dev/sda1 447.1G__ext4__unlabeled__Sandisk_SDSSDXP480G
	while read -r dev size; do
		[[ $dev && $size ]] || continue
		s=${size%%__*}
		size_t="${s: -1:1}"
		isize=${s:0:-1}
		# find the root device: /dev/sda1 -> /dev/sda, /dev/nvme0n1p12 -> /dev/nvme0n1
		drive="$(sed 's/p\?[1-9][0-9]*$//' <<<"$dev")"
		model=$(lsblk -lno MODEL "$drive" | awk '{gsub(/ |\t/, "_"); print}')
		model=$(sed 's/^\s*//; s/\s*$//' <<<"$model")
		[[ $size_t == 'K' || ($size_t == 'M' && ${isize%.*} -lt 80) ]] || printf "%s\n" "$dev ${size}__$model"
	done < <(lsblk -lno TYPE,PATH,SIZE,FSTYPE,LABEL $part |
		awk "/$regexp/"' && !'"/${IGNORE_DEV:-NONEXX}/"' {
			if ($4 == "") {
				$4 = "unformatted"
			}
			if ($5 == "") {
				$5 = "unlabeled"
			}
			print $2, $3 "__" $4 "__" $5
		}')
}

part_format() {
	local part="$1"
	local fs="$2"
	local delay="$3"

	msg "File System Format" "\nFormatting $part as $fs\n" 0

	if [[ $fs == 'f2fs' && -z $PF2FS ]]; then
		modprobe f2fs
		PF2FS=true
		sleep 1
	elif [[ $fs == 'btrfs' && -z $PBTRFS ]]; then
		modprobe btrfs
		PBTRFS=true
		sleep 1
	fi

	mkfs.$fs ${FS_CMD_FLAGS[$fs]} "$part" >/dev/null 2>"$ERR" || mkfs.$fs ${FS_CMD_FLAGS[$fs]} "$part" >/dev/null 2>"$ERR"
	errshow 0 "mkfs.$fs ${FS_CMD_FLAGS[$fs]} $part" || return 1
	sleep "$delay"
}

part_device() {
	if [[ $DEV_COUNT -eq 1 && $DEVS ]]; then
		DEVICE="$(awk '{print $1}' <<<"$DEVS")"
	elif ((DEV_COUNT > 1)); then
		if [[ $1 ]]; then
			dlg DEVICE menu "Boot Device" "\nSelect the device to use for bootloader install." $DEVS
		else
			dlg DEVICE menu "Select Device" "$_device" $DEVS
		fi
		[[ $DEVICE ]] || return 1
	elif [[ $DEV_COUNT -lt 1 && ! $1 ]]; then
		msg "Device Error" "\nNo available devices.\n\nExiting..\n" 2
		die 1
	fi

	[[ $1 ]] && BOOT_D="$DEVICE"

	return 0
}

part_bootdev() {
	BOOT_D="${BOOT%[1-9]}"
	BOOT_NUM="${BOOT: -1}"
	[[ $BOOT = /dev/nvme* ]] && BOOT_D="${BOOT%p[1-9]}"
	if [[ $SYS == 'UEFI' ]]; then
		parted -s $BOOT_D set $BOOT_NUM esp on >/dev/null 2>&1
	else
		parted -s $BOOT_D set $BOOT_NUM boot on >/dev/null 2>&1
	fi
	return 0
}

part_cryptlv() {
	local part="$1" devs=""
	devs="$(lsblk -lno NAME,FSTYPE,TYPE)"

	# Identify if $part is LUKS+LVM, LVM+LUKS, LVM alone, or LUKS alone
	if lsblk -lno TYPE "$part" | grep -q 'crypt'; then
		LUKS='encrypted'
		LUKS_NAME="${part#/dev/mapper/}"
		for dev in $(awk '/lvm/ && /crypto_LUKS/ {print "/dev/mapper/"$1}' <<<"$devs" | sort | uniq); do
			if lsblk -lno NAME "$dev" | grep -q "$LUKS_NAME"; then
				LUKS_DEV="${LUKS_DEV}cryptdevice=$dev:$LUKS_NAME "
				LVM='logical volume'
				break
			fi
		done
		for dev in $(awk '/part/ && /crypto_LUKS/ {print "/dev/"$1}' <<<"$devs" | sort | uniq); do
			if lsblk -lno NAME "$dev" | grep -q "$LUKS_NAME"; then
				LUKS_UUID="$(lsblk -lno UUID,TYPE,FSTYPE "$dev" | awk '/part/ && /crypto_LUKS/ {print $1}')"
				LUKS_DEV="${LUKS_DEV}cryptdevice=UUID=$LUKS_UUID:$LUKS_NAME "
				break
			fi
		done
	elif lsblk -lno TYPE "$part" | grep -q 'lvm'; then
		LVM='logical volume'
		VNAME="${part#/dev/mapper/}"
		for dev in $(awk '/crypt/ && /lvm2_member/ {print "/dev/mapper/"$1}' <<<"$devs" | sort | uniq); do
			if lsblk -lno NAME "$dev" | grep -q "$VNAME"; then
				LUKS_NAME="${dev/\/dev\/mapper\//}"
				break
			fi
		done
		for dev in $(awk '/part/ && /crypto_LUKS/ {print "/dev/"$1}' <<<"$devs" | sort | uniq); do
			if lsblk -lno NAME "$dev" | grep -q "$LUKS_NAME"; then
				LUKS_UUID="$(lsblk -lno UUID,TYPE,FSTYPE "$dev" | awk '/part/ && /crypto_LUKS/ {print $1}')"
				LUKS_DEV="${LUKS_DEV}cryptdevice=UUID=$LUKS_UUID:$LUKS_NAME "
				LUKS='encrypted'
				break
			fi
		done
	fi
}

part_countdec() { # loop all passed partitions and remove them from the list, decrementing the counter
	for p; do
		if ((PART_COUNT)); then
			PARTS="$(sed "/${p##*/} /d" <<<"$PARTS")" # sed //d doesn't like slashes so strip the everything to the last slash
			((PART_COUNT--))
		fi
	done
}

###############################################################################
# mounting menus
# mount_menu is the entry point which calls all other functions
# once finished it returns to the main menu: main()

mount_menu() {
	is_bg_install || return 0
	msg "Mount Menu" "\nGathering device and partition information.\n" 1
	lvm_detect
	umount_dir "$MNT"
	if ! part_find 'part|lvm|crypt'; then
		dev_menu "$_errpart"
		if ! part_find 'part|lvm|crypt'; then
			SEL=0
			return 1
		fi
	fi
	# we don't show the underlying partition(s) for LVM and/or LUKS
	[[ $LUKS && $LUKS_PART ]] && part_countdec $LUKS_PART
	[[ $LVM && $LVM_PARTS ]] && part_countdec $LVM_PARTS
	mount_root || {
		ROOT=''
		return 1
	}
	mount_boot || {
		BOOT=''
		return 1
	}
	if [[ $BOOT ]]; then
		part_mount "$BOOT" "/boot" || return 1
		part_bootdev
		SEP_BOOT=true
	fi
	mount_swap || return 1
	mount_extra || return 1
	install_background
	return 0
}

mount_boot() {
	local s pts dev size isize ptcount=0

	if [[ -z $BOOT ]]; then
		if [[ $AUTO_BOOT && -z $LVM && -z $LUKS ]]; then
			BOOT="$AUTO_BOOT"
			return 0
		fi

		if ((PART_COUNT)); then
			while read -r dev size; do # walk partition list and skip ones that are too small/big for boot
				[[ $dev && $size ]] || continue
				s=${size%%__*}
				size_t="${s: -1:1}"
				isize=${s:0:-1}
				if ! [[ $size_t == 'T' || ($size_t == 'G' && ${isize%.*} -gt 2) ]]; then
					pts+="$dev $size "
					((ptcount++))
				fi
			done <<<"$PARTS"
		fi

		local txt="\nNo partitions available that meet size requirements!!\n\nReturning to the main menu.\n"

		case "$SYS" in
		UEFI)
			case "$ptcount" in
			0)
				msg "EFI Boot Partition" "$txt" 2
				return 1
				;;
			1)
				msg "EFI Boot Partition" "\nOnly one partition that meets size requirements for boot (/boot).\n" 1
				BOOT="$(awk 'NF > 0 {print $1}' <<<"$pts")"
				;;
			*)
				dlg BOOT menu "EFI Boot Partition" "$_uefi" $pts
				;;
			esac
			[[ $BOOT ]] || return 1
			;;
		BIOS)
			if [[ $LUKS && ! $LVM ]]; then
				case "$ptcount" in
				0)
					txt="\nLUKS without LVM requires a separate boot partition.$txt"
					msg "Boot Partition" "$txt" 2
					return 1
					;;
				1)
					msg "Boot Partition" "\nOnly one partition that meets size requirements for boot (/boot).\n" 1
					BOOT="$(awk 'NF > 0 {print $1}' <<<"$pts")"
					;;
				*)
					dlg BOOT menu "Legacy Boot Partition" "$_biosluks" $pts
					;;
				esac
				[[ $BOOT ]] || return 1
			else
				((!ptcount)) && return 0
				dlg BOOT menu "Boot Partition" "$_bios" "skip" "no separate boot" $pts
				if [[ -z $BOOT || $BOOT == "skip" ]]; then
					BOOT=''
					return 0
				fi
			fi
			;;
		esac
	fi

	local fs
	fs="$(fsck -N "$BOOT")"

	case "$SYS" in
	UEFI) BOOTFS='vfat' ;;
	BIOS) BOOTFS='ext4' ;;
	esac

	if ([[ $SYS == 'BIOS' ]] && grep -q 'ext[34]' <<<"$fs") || ([[ $SYS == 'UEFI' ]] && grep -q 'fat' <<<"$fs"); then
		yesno "Format Boot Partition" "\nIMPORTANT: $BOOT $_format" "Format" "Do Not Format" 1 || return 0
	fi

	part_format "$BOOT" "$BOOTFS" 2 || return 1
	return 0
}

mount_root() {
	local pts dev size isize ptcount=0

	if [[ -z $ROOT ]]; then
		if [[ $AUTO_ROOT && -z $LVM && -z $LUKS ]]; then
			ROOT="$AUTO_ROOT"
			msg "Mount Menu" "\nUsing partitions created during automatic format.\n" 2
			part_mount "$ROOT" || {
				AUTO_ROOT='' ROOT=''
				return 1
			}
			return 0 # we're done here
		else      # walk partition list and skip ones that are < 8G
			while read -r dev size; do
				[[ $dev && $size ]] || continue
				s=${size%%__*}
				size_t="${s: -1:1}"
				isize=${s:0:-1}
				if ! [[ $size_t == 'M' || ($size_t == 'G' && ${isize%.*} -lt 8) ]]; then
					pts+="$dev $size "
					((ptcount++))
				fi
			done <<<"$PARTS"

			if ((ptcount == 1)); then # only one available device
				msg "Root Partition (/)" "\nOnly one that meets size requirements for root (/).\n" 2
				ROOT="$(awk 'NF > 0 {print $1}' <<<"$pts")"
			else
				local txt="\nSelect the root (/) partition, this is where $DIST will be installed."
				txt+="\n\nDevices smaller than 8G will not be shown here."
				dlg ROOT menu "Root Partition" "$txt" $pts
			fi
		fi
	fi

	if [[ $ROOT ]]; then
		mount_filesystem "$ROOT" || return 1
		part_mount "$ROOT" || return 1
		if ((BTRFS == 2)); then
			btrfs_subvols "$ROOT" || return 1
		fi
		BTRFS=0
		return 0
	fi

	# should never reach here unless an error occurred
	ROOT=''
	return 1
}

mount_swap() {
	local pts dev size isize

	if ((PART_COUNT)); then
		while read -r dev size; do # walk partition list and skip ones that are > 64G
			[[ $dev && $size ]] || continue
			s=${size%%__*}
			size_t="${s: -1:1}"
			isize=${s:0:-1}
			if ! [[ $size_t == 'T' || ($size_t == 'G' && ${isize%.*} -gt 64) ]]; then
				pts+="$dev $size "
			fi
		done <<<"$PARTS"
	fi

	dlg SWAP menu "Swap Setup" "\nSelect whether to use a swapfile, swap partition, or none." \
		"none" "No swap space" \
		"swapfile" "/swapfile (editable size)" \
		$pts

	if [[ -z $SWAP || $SWAP == "none" ]]; then
		SWAP=''
		return 0
	elif [[ $SWAP == "swapfile" ]]; then
		local i=0
		until [[ ${SWAP_S:0:1} =~ [1-9] && ${SWAP_S: -1} =~ (M|G) ]]; do
			if ((i > 0)); then
				msg "Swap Size Error" \
					"\nSwap size must be 1(M|G) or greater, and can only contain whole numbers\n\nSize entered: $SWAP_S\n" 2
			fi
			if ! dlg SWAP_S input "Swap Setup" "$_swapsize" "$MEM"; then
				SWAP=''
				SWAP_S=''
				return 1
			fi
			((i++))
		done
		part_swap "$MNT/$SWAP"
		SWAP="/$SWAP"
	else
		part_swap "$SWAP"
		part_countdec "$SWAP"
		SWAP_S="$(lsblk -lno SIZE $SWAP)"
	fi
	return 0
}

mount_extra() {
	local part dev size

	# walk partition list and skip ones that are < 1G
	if ((PART_COUNT)); then
		while read -r dev size; do
			[[ $dev && $size ]] || continue
			s=${size%%__*}
			[[ ${s: -1:1} == 'M' ]] && part_countdec "$dev"
		done <<<"$PARTS"
	fi

	while ((PART_COUNT)); do
		part=''
		dlg part menu 'Mount Extra' "$_expart" 'done' 'finish mounting step' $PARTS || break
		if [[ $part == 'done' ]]; then
			break
		elif mount_filesystem "$part" && mount_mountpoint && part_mount "$part" "$EXMNT"; then
			if ((BTRFS == 2)); then
				btrfs_subvols "$part" "$EXMNT" || return 1
			fi
			EXMNTS+="$part: $EXMNT "
			[[ $EXMNT == '/usr' && $HOOKS != *usr* ]] && HOOKS+=" usr"
			BTRFS=0
		else
			return 1
		fi
	done
	return 0
}

mount_opts() {
	local part="$1"
	local fs="$2"
	local opts=''
	local title="${fs^} Mount Options"

	yesno "$title" "\nMount $part with default mount options?\n" && return 1
	for i in ${FS_OPTS[$fs]}; do
		opts+="$i - off "
	done
	until [[ $MNT_OPTS ]]; do
		dlg MNT_OPTS check "$title" "$_mount" $opts || return 1 # no options is auto mount
		MNT_OPTS="${MNT_OPTS// /,}"
		yesno "$title" "\nConfirm mount options: $MNT_OPTS\n" || MNT_OPTS=''
	done
	return 0
}

mount_filesystem() {
	local part="$1"
	local fs=''
	local cur txt
	cur="$(lsblk -lno FSTYPE "$part" 2>/dev/null)"
	txt="\nSelect which file system to use for $(part_pretty "$part")\n\ndefault:  ext4"

	if [[ $cur ]]; then
		# bail early if the partition was created in part_auto()
		[[ $part == "$AUTO_ROOT" ]] && return 0
		txt+="\nexisting:  $cur"
	fi

	BTRFS=0
	until [[ $fs ]]; do
		dlg fs menu "File System" "$txt" $([[ $cur ]] && printf "skip -") \
			ext4 "The evolution of the most used Linux file system, successor to Ext3" \
			ext3 "Third extended file system, successor to Ext2" \
			ext2 "Second extended file system, unlike 3/4 it is not journaled and obsolete" \
			vfat "File allocation table, a legacy file system which is simple and robust" \
			btrfs "A modern copy on write file system with advanced features, fault tolerance, repair, and easy administration" \
			ntfs "NT file system, a journaling file system created by Microsoft" \
			f2fs "Flash-friendly file system, intended for NAND-based flash memory" \
			jfs "Journaled file system created by IBM and open-sourced in 1999" \
			xfs "Journaled file system created by Silicon Graphics Inc. (SGI)" \
			nilfs2 "A log-structured file system implementation for the Linux kernel" \
			reiserfs "Journaled file system created by a team at Namesys led by Hans Reiser" || return 1

		[[ $fs == 'skip' ]] && return 0
		yesno "File System" "\nFormat $part as $fs?\n" || fs=''
	done

	[[ $part == "$ROOT" ]] && ROOTFS=$fs
	part_format "$part" "$fs" 1

	if [[ $fs == 'btrfs' ]]; then
		BTRFS=1
		yesno "Btrfs Subvolumes" "$_btrfs" && BTRFS=2
	fi
}

mount_mountpoint() {
	EXMNT=''
	until [[ $EXMNT ]]; do
		dlg EXMNT input "Extra Mount $(part_pretty "$part")" "$_exmnt" "/" || return 1
		if [[ ${EXMNT:0:1} != "/" || ${#EXMNT} -le 1 || $EXMNT =~ \ |\' || $EXMNTS == *"$EXMNT"* ]]; then
			msg "Mountpoint Error" "$_errexpart"
			EXMNT=''
		fi
	done
	return 0
}

###############################################################################
# installation
# main is the entry point which calls all other install functions, once
# complete it shows a dialog to edit files on the new system before reboot

install_main() {
	install_base
	genfstab -U "$MNT" >"$MNT/etc/fstab" 2>"$ERR"
	errshow 1 "genfstab -U '$MNT' > '$MNT/etc/fstab'"
	[[ -f $MNT/swapfile ]] && sed -i "s~${MNT}~~" "$MNT/etc/fstab"
	install_packages
	install_tearfree
	install_mkinitcpio
	install_bootldr
	chrun "hwclock --systohc --utc" || chrun "hwclock --systohc --utc --directisa"
	install_user
	install_login

	# make sure the new user owns files in their $HOME
	chrun "chown -Rf $NEWUSER:1000 /home/$NEWUSER"

	# changing distro name?
	if [[ -f "$MNT/etc/os-release" ]] && ! grep -q "$DIST" "$MNT/etc/os-release"; then
		n=$(awk '/^NAME=/ {gsub(/^NAME=|"|'\''/, ""); print $1}' "$MNT/etc/os-release" 2>/dev/null)
		sed -i "s/$n/$DIST/g" "$MNT/etc/os-release"
		sed -i "s/$n/$DIST/g" "$MNT/etc/lsb-release"
	fi

	# allow members of the wheel group to run commands as root
	sed -i 's/^# \(%wheel ALL=(ALL.*) ALL\)$/\1/g' "$MNT/etc/sudoers"

	if [[ "$USERCMD" ]]; then
		chrun "$USERCMD" 2>"$ERR" 2>&1
		errshow 0 "chrun '$USERCMD'"
	fi

	while :; do
		dlg choice menu "Finalization" "$_edit" \
			finished "exit the installer and reboot" \
			keyboard "${EDIT_FILES[keyboard]}" \
			console "${EDIT_FILES[console]}" \
			locale "${EDIT_FILES[locale]}" \
			hostname "${EDIT_FILES[hostname]}" \
			sudoers "${EDIT_FILES[sudoers]}" \
			mkinitcpio "${EDIT_FILES[mkinitcpio]}" \
			fstab "${EDIT_FILES[fstab]}" \
			crypttab "${EDIT_FILES[crypttab]}" \
			bootloader "${EDIT_FILES[bootloader]}" \
			pacman "${EDIT_FILES[pacman]}" \
			login "${EDIT_FILES[login]}"

		if [[ -z $choice || $choice == 'finished' ]]; then
			[[ $DEBUG == true && -r $DBG ]] && ${EDITOR:-vim} "$DBG"
			clear
			die 127
		else
			for f in ${EDIT_FILES[$choice]}; do
				if [[ -e ${MNT}$f ]]; then
					${EDITOR:-vim} "${MNT}$f"
				else
					msg "File Missing" "\nOne or more of the files selected do not exist:\n\n${MNT}$f\n"
				fi
			done
		fi
	done
}

install_base() {
	clear
	tput cnorm
	if [[ $BG_PID ]] && kill -0 $BG_PID 2>/dev/null; then
		[[ -e /tmp/wmlist ]] && rm -f /tmp/wmlist
		printf "\nA background install process is still running, tailing the output...\n\n"
		tail -f --pid=$BG_PID "$BG"
		trap - EXIT
		unset BG_PID
	fi

	mkdir -pv "$MNT/etc/default"

	if [[ $DIST == "Syncopated" ]]; then
		# we have some customizations in /etc on the iso we want to preserve
		cp -vf /etc/os-release "$MNT/etc/"
		cp -vf /etc/lsb-release "$MNT/etc/"
		cp -vf /etc/modprobe.d "$MNT/etc/"
		cp -rfv /etc/sysctl.d "$MNT/etc/"
		cp -rfv /etc/sway "$MNT/etc/"
		mkdir -p "$MNT/etc/xdg/autostart/"
		cp -vf /etc/xdg/autostart/live-installer.desktop "$MNT/etc/xdg/autostart/live-installer.desktop"
		cp -vf /etc/skel/.zshrc "$MNT/etc/skel/.zshrc"
		cp -vf /etc/skel/.zshenv "$MNT/etc/skel/.zshenv"
		cp -vf /etc/skel/.zprofile "$MNT/etc/skel/.zprofile"
		cp -vf /etc/skel/.Xresources "$MNT/etc/skel/.Xresources"
		cp -vf /etc/skel/.xprofile "$MNT/etc/skel/.xprofile"
		cp -vf /etc/skel/.xinitrc "$MNT/etc/skel/.xinitrc"
		# cp -vf /etc/skel/.gtkrc-2.0 "$MNT/etc/skel/.gtkrc-2.0"
		cp -rfv /etc/skel/.config "$MNT/etc/skel/"
		cp -rfv /etc/skel/.local "$MNT/etc/skel/"
		mkdir -p "$MNT/usr/share/themes/"
		# cp -rfv /usr/share/themes/oomox-soundbot "$MNT/usr/share/themes/"
		mkdir -p "$MNT/usr/share/backgrounds/"
		cp -rfv /usr/share/backgrounds/syncopated "$MNT/usr/share/backgrounds/"
	else
		zshrc
	fi

	# copy network settings
	[[ -d /var/lib/iwd ]] && cp -rfv /var/lib/iwd "$MNT/var/lib/"
	[[ -f /etc/resolv.conf ]] && cp -fv /etc/resolv.conf "$MNT/etc/"
	[[ -d /etc/netctl/interfaces ]] && cp -rfv /etc/netctl/interfaces "$MNT/etc/netctl/"
	[[ -d /etc/NetworkManager/system-connections ]] && cp -rvf /etc/NetworkManager/system-connections "$MNT/etc/NetworkManager/"

	# stop pacman complaining
	mkdir -p "$MNT/var/lib/pacman/sync"
	touch "$MNT"/var/lib/pacman/sync/{core.db,extra.db,community.db}

	echo "LANG=$LOCALE" >"$MNT/etc/locale.conf"
	cp -fv "$MNT/etc/locale.conf" "$MNT/etc/default/locale"
	sed -i "s/#en_US.UTF-8/en_US.UTF-8/g; s/#${LOCALE} /${LOCALE} /g" "$MNT/etc/locale.gen"
	chrun "locale-gen"
	chrun "ln -svf /usr/share/zoneinfo/$ZONE/$SUBZ /etc/localtime"

	# touchpad config
	mkdir -pv "$MNT/etc/X11/xorg.conf.d/"
	cat >"$MNT/etc/X11/xorg.conf.d/40-touchpad.conf" <<-EOF
		Section "InputClass"
		    Identifier "touchpad"
		    Driver "libinput"
		    MatchIsTouchpad "on"
		    Option "Tapping" "on"
		    Option "TappingDrag" "on"
		    Option "AccelSpeed" "0.5"
		    Option "AccelProfile" "adaptive"
		    Option "ScrollMethod" "twofinger"
		    Option "MiddleEmulation" "on"
		    Option "DisableWhileTyping" "on"
		    Option "TappingButtonMap" "lrm"
		EndSection

		Section "InputClass"
		    Identifier      "touchpad-ignore-duplicates"
		    MatchIsTouchpad "on"
		    MatchOS         "Linux"
		    MatchDevicePath "/dev/input/mouse*"
		    Option          "Ignore" "on"
		EndSection

		Section "InputClass"
		    Identifier  "clickpad-buttons"
		    MatchDriver "libinput"
		    Option      "SoftButtonAreas" "50% 0 82% 0 0 0 0 0"
		    Option      "SecondarySoftButtonAreas" "58% 0 0 15% 42% 58% 0 15%"
		EndSection

		Section "InputClass"
		    Identifier   "Disable-clickpad-buttons-on-Apple-touchpads"
		    MatchProduct "Apple|bcm5974"
		    MatchDriver  "libinput"
		    Option       "SoftButtonAreas" "0 0 0 0 0 0 0 0"
		EndSection
	EOF

	cat >"$MNT/etc/X11/xorg.conf.d/00-keyboard.conf" <<-EOF
		# Use localectl(1) to instruct systemd-localed to update it.
		Section "InputClass"
		    Identifier      "system-keyboard"
		    MatchIsKeyboard "on"
		    Option          "XkbLayout" "$KEYMAP"
		EndSection
	EOF

	cat >"$MNT/etc/default/keyboard" <<-EOF
		# KEYBOARD CONFIGURATION FILE
		# Consult the keyboard(5) manual page.
		XKBMODEL=""
		XKBLAYOUT="$KEYMAP"
		XKBVARIANT=""
		XKBOPTIONS=""
		BACKSPACE="guess"
	EOF
	printf "KEYMAP=%s\nFONT=%s\n" "$CMAP" "$FONT" >"$MNT/etc/vconsole.conf"

	echo "$NEWHOST" >"$MNT/etc/hostname"
	cat >"$MNT/etc/hosts" <<-EOF
		127.0.0.1 localhost
		127.0.1.1 $NEWHOST
		::1         localhost ip6-localhost ip6-loopback
		ff02::1    ip6-allnodes
		ff02::2    ip6-allrouters
	EOF
}

install_user() {
	local i=0
	local groups='audio,realtime,video,input,log,rfkill,wheel'

	echo "Setting root user password and shell"
	chrun "chpasswd <<< 'root:$ROOT_PASS'" 2>"$ERR" 2>&1
	errshow 1 "chrun 'chpasswd <<< \"root:$ROOT_PASS\"'"
	if [[ $NEWSHELL != 'zsh' ]]; then # root uses zsh by default
		chrun "usermod -s /bin/$NEWSHELL root" 2>"$ERR" 2>&1
		errshow 1 "chrun 'usermod -s /bin/$NEWSHELL root'"
		# copy the default mkshrc to /root if it was selected
		[[ $NEWSHELL == 'mksh' ]] && cp -fv "$MNT/etc/skel/.mkshrc" "$MNT/root/.mkshrc"
	fi

	echo "Creating user $NEWUSER and setting password"

	# check if there's an existing user home for new user (separate /home partition)
	[[ -d "$MNT/home/$NEWUSER" ]] && i=1

	chrun "useradd -m -G $groups -s /bin/$NEWSHELL -U $NEWUSER" 2>"$ERR" 2>&1
	errshow 1 "chrun 'useradd -m -G $groups -s /bin/$NEWSHELL -U $NEWUSER'"
	chrun "chpasswd <<< '$NEWUSER:$USER_PASS'" 2>"$ERR" 2>&1
	errshow 1 "chrun 'chpasswd <<< \"$NEWUSER:$USER_PASS\"'"

	if [[ $INSTALL_WMS == *dwm* ]]; then
		local dir="/home/$NEWUSER/suckless"
		mkdir -pv "$dir"
		for i in dwm dmenu st; do
			if chrun "git clone 'https://git.suckless.org/$i' '$dir/$i'"; then
				chrun "cd '$dir/$i' && make PREFIX=/usr install"
			else
				printf "failed to clone %s repo\n" "$i"
			fi
		done

		mkdir -p "$MNT/usr/share/xsessions"
		cat >"$MNT/usr/share/xsessions/dwm.desktop" <<-EOF
			[Desktop Entry]
			Encoding=UTF-8
			Name=Dwm
			Comment=Dynamic Window Manager
			Exec=dwm
			TryExec=dwm
			Type=Application
		EOF
	fi

	# upgrade existing home with new skeleton configs, making backups when needed
	((i)) && cp -rfaT -b --suffix='.bak' "$MNT/etc/skel/" "$MNT/home/$NEWUSER"

	# cleanup the new home folder

	# remove tint2 configs if bspwm and openbox aren't being installed
	[[ $INSTALL_WMS =~ (bspwm|openbox) ]] || rm -rf "$MNT/home/$NEWUSER/.config/tint2"

	# remove jgmenu configs if bspwm, fluxbox, or openbox aren't being installed
	[[ $INSTALL_WMS =~ (fluxbox|bspwm|openbox) ]] || rm -rf "$MNT/home/$NEWUSER/.config/jgmenu"

	# remove geany configs if it wasn't installed
	[[ ${USER_PKGS[*]} != *geany* ]] && rm -rf "$MNT/home/$NEWUSER/.config/geany"

	# remove shell stuff for unused shells
	[[ $NEWSHELL != 'bash' ]] && rm -rf "$MNT/home/$NEWUSER/.bash"*
	[[ $NEWSHELL != 'zsh' ]] && rm -rf "$MNT/home/$NEWUSER/.z"*

	cat >>"$MNT/etc/profile" <<-EOF
		# add ~/.local/bin to the PATH
		echo \$PATH | grep -q "/home/$NEWUSER/.local/bin:" || export PATH="/home/$NEWUSER/.local/bin:\$PATH"
	EOF

	# failed to install some AL packages so put a list in a script for the user to install later
	if [[ "${FAIL_PKG[*]}" ]]; then
		cat >"$MNT/home/$NEWUSER/packages" <<-EOF
			#!/bin/bash
			sudo pacman -Syyu ${FAIL_PKG[*]} --needed --noconfirm || exit
			rm -f /home/$NEWUSER/packages"
		EOF
	fi
}

install_login() {
	AUTOLOGIN_SERV="$MNT/etc/systemd/system/getty@tty1.service.d"

	if [[ -z $LOGIN_TYPE ]]; then
		rm -rf "$AUTOLOGIN_SERV"
		return 0
	fi

	echo "Setting up $LOGIN_TYPE"

	if [[ $LOGIN_TYPE != 'console' ]]; then
		rm -rf "$AUTOLOGIN_SERV" "$MNT/home/$NEWUSER/.xinitrc"
		chrun "systemctl enable $LOGIN_TYPE.service" 2>"$ERR"
		errshow 1 "chrun 'systemctl enable $LOGIN_TYPE.service'"
	fi

	config_${LOGIN_TYPE}
}

install_bootldr() {
	local uuid_type="UUID" url=''
	local offset=0 pagesize=0

	echo "Installing $BOOTLDR"

	if [[ $ROOT == /dev/mapper* ]]; then
		ROOT_ID="$ROOT"
	else
		[[ $BOOTLDR =~ (systemd-boot|efistub) ]] && uuid_type="PARTUUID"
		ROOT_ID="$uuid_type=$(blkid -s $uuid_type -o value $ROOT)"
	fi

	if [[ $SYS == 'UEFI' ]]; then
		# remove our old install and generic BOOT/ dir
		echo "Removing conflicting boot directories"
		if [[ -d "$MNT/boot/EFI/${DIST,,}" ]]; then
			find "$MNT/boot/EFI/" -maxdepth 1 -mindepth 1 -iname "${DIST,,}" -type d -delete -printf "remove %p\n"
			find "$MNT/boot/EFI/" -maxdepth 1 -mindepth 1 -iname 'BOOT' -type d -delete -printf "remove %p\n"
		fi
	fi

	if [[ $SWAP ]]; then # attempt to setup swap space for suspend/resume
		if [[ $SWAP == /dev/mapper* ]]; then
			RESUME="resume=$SWAP "
		elif [[ $SWAP == "/swapfile" ]]; then
			if [[ $BTRFS_MNT ]]; then
				url='https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c'
				pagesize="$(getconf PAGESIZE)"
				curl -fsSL "$url" -o btrfs_map_physical.c
				gcc -O2 -o btrfs_map_physical btrfs_map_physical.c
				offset="$(./btrfs_map_physical "${MNT}$SWAP" | awk -v i=$pagesize '{if ($1 == "0") {print $NF / i}}')"
			else
				offset="$(filefrag -v "${MNT}$SWAP" | awk '{if ($1 == "0:") {gsub(/\./, ""); print $4}}')"
			fi
			RESUME="resume=$ROOT_ID resume_offset=$offset "
		else
			RESUME="resume=$uuid_type=$(blkid -s $uuid_type -o value "$SWAP") "
		fi
	fi

	prerun_$BOOTLDR
	chrun "${BCMDS[$BOOTLDR]}" 2>"$ERR" 2>&1
	errshow 1 "chrun '${BCMDS[$BOOTLDR]}'"

	if [[ -d $MNT/hostrun ]]; then
		echo "Unmounting chroot directories"
		# cleanup the bind mounts we made earlier for the grub-probe module
		umount_dir "$MNT/hostrun/"{udev,lvm}
		rm -rf "$MNT/hostrun" >/dev/null 2>&1
	fi

	if [[ $SYS == 'UEFI' ]]; then
		# some UEFI firmware requires a generic esp/BOOT/BOOTX64.EFI
		mkdir -pv "$MNT/boot/EFI/BOOT"
		case "$BOOTLDR" in
		grub)
			cp -fv "$MNT/boot/EFI/${DIST,,}/grubx64.efi" "$MNT/boot/EFI/BOOT/BOOTX64.EFI"
			;;
		syslinux)
			cp -rf "$MNT/boot/EFI/syslinux/"* "$MNT/boot/EFI/BOOT/"
			cp -f "$MNT/boot/EFI/syslinux/syslinux.efi" "$MNT/boot/EFI/BOOT/BOOTX64.EFI"
			;;
		esac
	fi

	return 0
}

install_packages() {
	typeset -ga FAIL_PKG=()
	typeset -a inpkg=() rmpkg=() goodinpkg=() alpkg=()

	inpkg=("${SES_PKGS[@]}" "${USER_PKGS[@]}" "$NEWSHELL")

	if [[ $INSTALL_WMS ]]; then
		inpkg+=("${BASE_PKGS[@]}" "${WM_PKGS[@]}")
		[[ -d /etc/NetworkManager/system-connections ]] && inpkg+=("network-manager-applet")
	fi

	for i in ${LOGIN_PKGS[$LOGIN_TYPE]}; do
		inpkg+=("$i")
	done

	blk="$(lsblk -f)"
	lspci | grep -qi 'broadcom' && inpkg+=('b43-firmware' 'b43-fwcutter' 'broadcom-wl')
	[[ $blk =~ ntfs ]] && inpkg+=('ntfs-3g')
	[[ $blk =~ jfs ]] && inpkg+=('jfsutils')
	[[ $blk =~ xfs ]] && inpkg+=('xfsprogs')
	[[ $blk =~ reiserfs ]] <<<"$blk" && inpkg+=('reiserfsprogs')
	[[ $LVM ]] && inpkg+=('lvm2')
	[[ $BTRFS_MNT || $blk =~ btrfs ]] && inpkg+=('btrfs-progs')
	[[ $NEWSHELL == 'zsh' ]] && inpkg+=('zsh-completions')
	[[ $NEWSHELL =~ (bash|zsh) ]] && inpkg+=('bash-completion')

	# needed to build dwm
	[[ $INSTALL_WMS =~ dwm ]] && inpkg+=('git' 'make' 'gcc' 'pkgconf')

	# remove the packages we don't want on the installed system
	[[ ${rmpkg[*]} ]] && chrun "pacman -Rnsc ${rmpkg[*]} --noconfirm"

	[[ -e $MNT/boot/${UCODE}.img ]] && rm -rf "$MNT/boot/${UCODE}.img"

	# install crucial packages first to avoid issues
	# reinstalling iputils fixes network issues for non-root users
	chrun "pacman -Syyu $KERNEL ${KERNEL}-headers $UCODE iputils --noconfirm" 2>"$ERR" 2>&1
	errshow 1 "chrun 'pacman -Syyu $KERNEL ${KERNEL}-headers $UCODE iputils --noconfirm'"

	# install the packages chosen throughout the install plus any extras added
	# check that packages we're trying to install are available, slow as shit
	# but I'm done doing this manually every time the arch repos change
	for pkg in "${inpkg[@]}"; do
		if pacman -Ssq "^$pkg$" >/dev/null 2>&1; then
			goodinpkg+=("$pkg")
		else
			echo "package missing or no longer available: $pkg -- ignoring"
			sleep 0.5
		fi
	done

	if [[ "${goodinpkg[*]}" ]]; then
		chrun "pacman -S ${goodinpkg[*]} --needed --noconfirm" 2>"$ERR" 2>&1
		errshow 1 "chrun 'pacman -S ${goodinpkg[*]} --needed --noconfirm'"
	fi

	# bootloader packages
	if [[ $BOOTLDR == 'grub' ]]; then
		chrun "pacman -S os-prober grub --needed --noconfirm" 2>"$ERR" 2>&1
		errshow 1 "chrun 'pacman -S os-prober grub --needed --noconfirm'"
	elif [[ $BOOTLDR == 'syslinux' ]]; then
		chrun "pacman -S syslinux --needed --noconfirm" 2>"$ERR" 2>&1
		errshow 1 "chrun 'pacman -S syslinux --needed --noconfirm'"
	fi
	if [[ $SYS == 'UEFI' ]]; then
		chrun "pacman -S efibootmgr --needed --noconfirm" 2>"$ERR" 2>&1
		errshow 1 "chrun 'pacman -S efibootmgr --needed --noconfirm'"
	fi

	if [[ $VIRT == 'oracle' ]]; then
		chrun "pacman -S ${KERNEL}-headers virtualbox-guest-utils virtualbox-guest-dkms --needed --noconfirm"
	fi

	chrun "pacman -Syyu --noconfirm" 2>"$ERR" 2>&1
	errshow 1 "chrun 'pacman -Syyu --noconfirm'"

	return 0
}

install_check_bg() {
	# check for errors in the background install
	[[ -e $MNT/bin/bash ]] && return

	local luks='' key="EF925EA60F33D0CB85C44AD13056513887B78AEB"

	[[ $LUKS ]] && luks='cryptsetup'

	{
		pacman-key --init
		pacman-key --populate
		pacman -Syy
		pacman -S archlinux-keyring --noconfirm
		pacstrap /mnt base rsync
	} >>/tmp/bgout 2>&1

	cp -Rf /etc/pacman.d "$MNT/etc/"
	cp -f /etc/pacman.conf "$MNT/etc/"
	cp -f /etc/pacman.d/mirrorlist "$MNT/etc/pacman.d/"
	cp -f /etc/pacman.d/chaotic-mirrorlist "$MNT/etc/pacman.d/"

	{
		chrun "pacman-key --init"
		chrun "pacman-key --populate"
		chrun "pacman -Sy --needed archlinux-keyring --noconfirm"
		chrun "pacman -Su"

		if pacman-key --list-keys | grep -q "expired.*Chaotic" || ! pacman-key --list-keys | grep -q "$key"; then
			chrun "pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com"
			chrun "pacman-key --lsign-key 3056513887B78AEB"
			chrun "yes | pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm"
			chrun "yes | pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm"
			chrun "pacman -Syu"
		fi

		chrun "pacman -S ${ISO_PKGS[*]} $luks $NET_TYPE --noconfirm --needed"

	} >>/tmp/bgout 2>&1

	if [[ $NET_TYPE == 'networkmanager' ]]; then
		chrun 'systemctl enable NetworkManager.service' >>/tmp/bgout 2>&1
	else
		chrun 'systemctl enable iwd.service' >>/tmp/bgout 2>&1
	fi

	if [[ -e /tmp/wmlist ]]; then
		chrun "pacman -S ${BASE_PKGS[*]} $(cat /tmp/wmlist) --noconfirm --needed" >>/tmp/bgout 2>&1
	fi
}

install_tearfree() {
	if [[ $VIRT != 'none' ]]; then
		[[ -e "$MNT/etc/X11/xorg.conf.d/40-touchpad.conf" ]] && rm -fv "$MNT/etc/X11/xorg.conf.d/40-touchpad.conf"
	elif [[ $TEARFREE ]]; then
		if lspci | grep ' VGA ' | grep -q 'Intel' && ! lspci | grep ' VGA ' | grep -qi 'NVIDIA'; then
			echo "Creating Intel Tear Free config /etc/X11/xorg.conf.d/20-intel.conf"
			cat >"$MNT/etc/X11/xorg.conf.d/20-intel.conf" <<-EOF
				Section "Device"
					Identifier  "Intel Graphics"
					Driver      "intel"
					Option      "TearFree" "true"
				EndSection
			EOF
			sed -i 's/xrender/glx/g' "$MNT/etc/skel/.config/picom.conf"
			cat "$MNT/etc/X11/xorg.conf.d/20-intel.conf"
		elif lspci | grep ' VGA ' | grep -q 'AMD/ATI.*RX\|AMD/ATI.*R[579]'; then # newer RX, R5, R7, and R9 cards can use the amdgpu driver
			echo "Creating AMD Tear Free config /etc/X11/xorg.conf.d/20-amdgpu.conf"
			cat >"$MNT/etc/X11/xorg.conf.d/20-amdgpu.conf" <<-EOF
				Section "Device"
					Identifier  "AMD Graphics"
					Driver      "amdgpu"
					Option      "TearFree" "true"
				EndSection
			EOF
			sed -i 's/xrender/glx/g' "$MNT/etc/skel/.config/picom.conf"
			cat "$MNT/etc/X11/xorg.conf.d/20-amdgpu.conf"
		elif lspci | grep ' VGA ' | grep -q 'AMD/ATI.*HD [2-6][0-9]*'; then # older HD 2xxx-6xxx cards must use the radeon driver
			echo "Creating Radeon Tear Free config /etc/X11/xorg.conf.d/20-radeon.conf"
			cat >"$MNT/etc/X11/xorg.conf.d/20-radeon.conf" <<-EOF
				Section "Device"
					Identifier  "AMD Graphics"
					Driver      "radeon"
					Option      "TearFree" "on"
				EndSection
			EOF
			sed -i 's/xrender/glx/g' "$MNT/etc/skel/.config/picom.conf"
			cat "$MNT/etc/X11/xorg.conf.d/20-radeon.conf"
		elif lspci | grep ' VGA ' | grep -q 'NVIDIA'; then
			echo "NVIDIA cards are currently unsupported for auto config"
		else
			echo "Unknown video card - aborting driver setup"
		fi
	fi
}

install_suckless() {
	local dir="/home/$NEWUSER/suckless"
	shift

	chrun "mkdir -pv '$dir'"

	for i in dwm dmenu st; do
		if chrun "git clone 'https://git.suckless.org/$i' '$dir/$i'"; then
			chrun "cd '$dir/$i' && make PREFIX=/usr install"
		else
			printf "failed to clone %s repo\n" "$i"
		fi
	done

	mkdir -p "$MNT/usr/share/xsessions"
	cat >"$MNT/usr/share/xsessions/dwm.desktop" <<-EOF
		[Desktop Entry]
		Encoding=UTF-8
		Name=Dwm
		Comment=Dynamic Window Manager
		Exec=dwm
		TryExec=dwm
		Type=Application
	EOF
}

install_mkinitcpio() {
	local add=''

	[[ $LUKS ]] && add+=" encrypt"
	[[ $LVM ]] && add+=" lvm2"
	[[ $SWAP ]] && add+=" resume"
	sed -i "s/block filesystems/block${add} filesystems ${HOOKS}/g" "$MNT/etc/mkinitcpio.conf"
	chrun "mkinitcpio -p $KERNEL" 2>"$ERR" 2>&1
	errshow 1 "chrun 'mkinitcpio -p $KERNEL'"
}

install_mirrorlist() {
	local url=''
	typeset -a args=("--verbose" "--connection-timeout" "2" "--threads" "10")

	# avoid SSL errors when the time is wrong
	timedatectl set-ntp 1 >/dev/null 2>&1 && timedatectl >/dev/null 2>&1

	# make a mirrorlist backup in case of issues
	[[ -f /etc/pacman.d/mirrorlist.bak ]] || cp -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

	if [[ $AUTO_MIRROR ]]; then
		reflector "${args[@]}" --download-timeout 2 --protocol https --sort rate --score 15 --fastest 20 --save /etc/pacman.d/mirrorlist
	else
		reflector "${args[@]}" -c "$MIRROR_COUNTRY" --download-timeout 2 --protocol https --sort rate --score 15 --fastest 20 --save /etc/pacman.d/mirrorlist
	fi

	chmod +r /etc/pacman.d/mirrorlist
}

install_background() {
	local luks='' key="EF925EA60F33D0CB85C44AD13056513887B78AEB"

	[[ $LUKS ]] && luks='cryptsetup'

	select_mirrors || AUTO_MIRROR=true
	(
		install_mirrorlist >/tmp/bgout 2>&1
		{
			pacman-key --init
			pacman-key --populate
			pacman -Syy
			pacman -S archlinux-keyring --noconfirm
			pacstrap /mnt base rsync
		} >>/tmp/bgout 2>&1

		cp -Rf /etc/pacman.d "$MNT/etc/"
		cp -f /etc/pacman.conf "$MNT/etc/"
		cp -f /etc/pacman.d/mirrorlist "$MNT/etc/pacman.d/"
		cp -f /etc/pacman.d/chaotic-mirrorlist "$MNT/etc/pacman.d/"

		{
			chrun "pacman-key --init"
			chrun "pacman-key --populate"
			chrun "pacman -Sy --needed archlinux-keyring --noconfirm"
			chrun "pacman -Su"

			if pacman-key --list-keys | grep -q "expired.*Chaotic" || ! pacman-key --list-keys | grep -q "$key"; then
				chrun "pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com"
				chrun "pacman-key --lsign-key 3056513887B78AEB"
				chrun "yes | pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm"
				chrun "yes | pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm"
				chrun "pacman -Syu"
			fi

			chrun "pacman -S ${ISO_PKGS[*]} $luks $NET_TYPE --noconfirm --needed"

		} >>/tmp/bgout 2>&1

		if [[ $NET_TYPE == 'networkmanager' ]]; then
			chrun 'systemctl enable NetworkManager.service' >>/tmp/bgout 2>&1
		else
			chrun 'systemctl enable iwd.service' >>/tmp/bgout 2>&1
		fi

		[[ -e /tmp/wmlist ]] &&
			chrun "pacman -S ${BASE_PKGS[*]} $(cat /tmp/wmlist) --noconfirm --needed" >>/tmp/bgout 2>&1
	) &

	BG_PID=$!
	# shellcheck disable=SC2064
	trap "kill $BG_PID 2> /dev/null; tput cnorm" EXIT
}

###############################################################################
# display manager config
# these are called based on which DM is chosen after it is installed
# additional config can be handled here, for now only lightdm and xinit.

config_ly() {
	cat >>"$MNT/home/$NEWUSER/$LOGINRC" <<-EOF
		# add ~/.local/bin to the PATH
		echo \$PATH | grep -q "\$HOME/.local/bin:" || export PATH="\$HOME/.local/bin:\$PATH"
	EOF
}

config_console() {
	if [[ $AUTOLOGIN ]]; then
		mkdir -p "$AUTOLOGIN_SERV"
		cat >"$AUTOLOGIN_SERV/autologin.conf" <<-EOF
			[Service]
			ExecStart=
			ExecStart=-/sbin/agetty -o '-p -f -- \\\u' --noclear --autologin $NEWUSER %I \$TERM
			Type=simple
			Environment=XDG_SESSION_TYPE=x11
		EOF
	else
		rm -rf "$AUTOLOGIN_SERV"
	fi

	if [[ $INSTALL_WMS ]]; then
		rm "$MNT/home/$NEWUSER/$LOGINRC"

		# run the session after logging in regardless of autologin
		cat >>"$MNT/home/$NEWUSER/$LOGINRC" <<-EOF
			# add ~/.local/bin to the PATH
			echo \$PATH | grep -q "\$HOME/.local/bin:" || export PATH="\$HOME/.local/bin:\$PATH"

			# automatically run startx when logging in on tty1
			[ -z "\$DISPLAY" ] && [ \$XDG_VTNR -eq 1 ] && startx
		EOF
	else
		rm -rf "$MNT/home/$NEWUSER/.xinitrc" "$MNT/root/.xinitrc"
		return 0
	fi

}

config_lightdm() {
	sed -i "/greeter-session=/ c greeter-session=lightdm-$LIGHTDM_GREETER" "$MNT/etc/lightdm/lightdm.conf"

	if [[ $LIGHTDM_GREETER == 'gtk-greeter' && $DIST == "Syncopated" ]]; then
		mkdir -p "$MNT/etc/lightdm"
		cat >"$MNT/etc/lightdm/lightdm-gtk-greeter.conf" <<-EOF
			[greeter]
			# default-user-image=/usr/share/icons/ArchLabs-Dark/64x64/places/distributor-logo-archlabs.png
			background=/usr/share/backgrounds/syncopated/syncopated003.jpg
			theme-name=Adwaita-dark
			icon-theme-name=Adwaita
			font-name=DejaVu Sans Mono 11
			position=30%,end 50%,end
		EOF
	fi
}

###############################################################################
# bootloader setup
# prerun_* set up the configs needed before actually running the commands
# setup_* are run after selecting a bootloader and build the command used later
# they can also be used for further user input as these run before control is taken away

setup_grub() {
	EDIT_FILES[bootloader]="/etc/default/grub"

	if [[ $SYS == 'BIOS' ]]; then
		[[ $BOOT_D ]] || { part_device 1 || return 1; }
		BCMDS[grub]="grub-install --verbose --recheck --force --target=i386-pc $BOOT_D"
	else
		BCMDS[grub]="mount -t efivarfs efivarfs /sys/firmware/efi/efivars > /dev/null 2>&1
		grub-install --verbose --recheck --force --target=x86_64-efi --efi-directory=/boot --bootloader-id='${DIST,,}'"
		grep -q /sys/firmware/efi/efivars /proc/mounts || mount -t efivarfs efivarfs /sys/firmware/efi/efivars >/dev/null 2>&1
	fi

	BCMDS[grub]="mkdir -p /run/udev /run/lvm && mount --bind /hostrun/udev /run/udev && mount --bind /hostrun/lvm /run/lvm &&
		${BCMDS[grub]} && grub-mkconfig -o /boot/grub/grub.cfg && sleep 1 && umount /run/udev /run/lvm"

	return 0
}

prerun_grub() {
	sed -i "s/GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR=\"${DIST}\"/g; s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/g" "$MNT/etc/default/grub"
	if [[ $LUKS_DEV ]]; then
		sed -i "s~#GRUB_ENABLE_CRYPTODISK~GRUB_ENABLE_CRYPTODISK~g; s~GRUB_CMDLINE_LINUX=.*~GRUB_CMDLINE_LINUX=\"${LUKS_DEV}\"~g" "$MNT/etc/default/grub"
	fi
	if [[ $SYS == 'BIOS' && $LVM && -z $SEP_BOOT ]]; then
		sed -i "s/GRUB_PRELOAD_MODULES=.*/GRUB_PRELOAD_MODULES=\"lvm\"/g" "$MNT/etc/default/grub"
	fi

	# fix network interface names changing after reboot
	# https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames/
	sed -i 's/\(GRUB_CMDLINE_LINUX=".*\)"/\1 net.ifnames=0"/g' "$MNT/etc/default/grub"

	# setup for os-prober module
	mkdir -p /run/{lvm,udev} "$MNT/hostrun/"{lvm,udev}
	mount --bind /run/lvm "$MNT/hostrun/lvm"
	mount --bind /run/udev "$MNT/hostrun/udev"
	if grep -q "GRUB_DISABLE_OS_PROBER" "$MNT/etc/default/grub"; then
		sed -i "s/.*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/g" "$MNT/etc/default/grub"
	else
		echo "GRUB_DISABLE_OS_PROBER=false" >>"$MNT/etc/default/grub"
	fi

	return 0
}

setup_efistub() {
	EDIT_FILES[bootloader]=""
}

prerun_efistub() {
	BCMDS[efistub]="mount -t efivarfs efivarfs /sys/firmware/efi/efivars > /dev/null 2>&1
		efibootmgr -v -d $BOOT_D -p $BOOT_NUM -c -L '${DIST} Linux' -l /vmlinuz-${KERNEL} \
			-u 'root=$ROOT_ID rw net.ifnames=0 $(
		[[ $BTRFS_MNT ]] && printf '%s ' "$BTRFS_MNT"
		[[ $UCODE ]] && printf 'initrd=\%s.img ' "$UCODE"
	)initrd=\initramfs-${KERNEL}.img'"
}

setup_syslinux() {
	if [[ $SYS == 'BIOS' ]]; then
		EDIT_FILES[bootloader]="/boot/syslinux/syslinux.cfg"
	else
		EDIT_FILES[bootloader]="/boot/EFI/syslinux/syslinux.cfg"
		BCMDS[syslinux]="mount -t efivarfs efivarfs /sys/firmware/efi/efivars > /dev/null 2>&1
		efibootmgr -v -c -d $BOOT_D -p $BOOT_NUM -l /EFI/syslinux/syslinux.efi -L $DIST"
	fi
}

prerun_syslinux() {
	local c="$MNT/boot/syslinux" s="/usr/lib/syslinux/bios"
	local d=".." # for non-UEFI systems we need to use ../path

	if [[ $SYS == 'UEFI' ]]; then
		c="$MNT/boot/EFI/syslinux" s="/usr/lib/syslinux/efi64" d=''
	fi

	mkdir -pv "$c"
	cp -rfv "$s/"* "$c/"
	cp -fv "/run/archiso/bootmnt/arch/boot/syslinux/splash.png" "$c/"

	cat >"$c/syslinux.cfg" <<-EOF
		UI vesamenu.c32
		MENU TITLE $DIST Boot Menu
		MENU BACKGROUND splash.png
		TIMEOUT 50
		DEFAULT ${DIST,,}

		# see: https://www.syslinux.org/wiki/index.php/Comboot/menu.c32
		MENU WIDTH 78
		MENU MARGIN 4
		MENU ROWS 4
		MENU VSHIFT 10
		MENU TIMEOUTROW 13
		MENU TABMSGROW 14
		MENU CMDLINEROW 14
		MENU HELPMSGROW 16
		MENU HELPMSGENDROW 29
		MENU COLOR border       30;44   #40ffffff #a0000000 std
		MENU COLOR title        1;36;44 #9033ccff #a0000000 std
		MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
		MENU COLOR unsel        37;44   #50ffffff #a0000000 std
		MENU COLOR help         37;40   #c0ffffff #a0000000 std
		MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
		MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
		MENU COLOR msg07        37;40   #90ffffff #a0000000 std
		MENU COLOR tabmsg       31;40   #30ffffff #00000000 std

		LABEL $DIST
		MENU LABEL $DIST Linux
		LINUX $d/vmlinuz-$KERNEL
		APPEND root=$ROOT_ID ${LUKS_DEV}${RESUME}rw net.ifnames=0$([[ $BTRFS_MNT ]] && printf ' %s' "$BTRFS_MNT")
		INITRD $([[ $UCODE ]] && printf "%s" "$d/$UCODE.img,")$d/initramfs-$KERNEL.img

		LABEL ${DIST}fallback
		MENU LABEL $DIST Linux Fallback
		LINUX $d/vmlinuz-$KERNEL
		APPEND root=$ROOT_ID ${LUKS_DEV}${RESUME}rw net.ifnames=0$([[ $BTRFS_MNT ]] && printf ' %s' "$BTRFS_MNT")
		INITRD $([[ $UCODE ]] && printf "%s" "$d/$UCODE.img,")$d/initramfs-$KERNEL-fallback.img
	EOF
	return 0
}

setup_systemd-boot() {
	EDIT_FILES[bootloader]="/boot/loader/entries/${DIST,,}.conf"
	BCMDS[systemd - boot]="mount -t efivarfs efivarfs /sys/firmware/efi/efivars > /dev/null 2>&1; systemd-machine-id-setup && bootctl --path=/boot install"
}

prerun_systemd-boot() {
	mkdir -pv "$MNT/boot/loader/entries"

	cat >"$MNT/boot/loader/loader.conf" <<-EOF
		default  ${DIST,,}.conf
		timeout  5
		editor   no
	EOF

	cat >"$MNT/boot/loader/entries/${DIST,,}.conf" <<-EOF
		title   $DIST Linux
		linux   /vmlinuz-${KERNEL}$([[ $UCODE ]] && printf "\ninitrd  %s" "/$UCODE.img")
		initrd  /initramfs-$KERNEL.img
		options root=$ROOT_ID ${LUKS_DEV}${RESUME}rw net.ifnames=0$([[ $BTRFS_MNT ]] && printf ' %s' "$BTRFS_MNT")
	EOF

	cat >"$MNT/boot/loader/entries/${DIST,,}-fallback.conf" <<-EOF
		title   $DIST Linux Fallback
		linux   /vmlinuz-${KERNEL}$([[ $UCODE ]] && printf "\ninitrd  %s" "/$UCODE.img")
		initrd  /initramfs-$KERNEL-fallback.img
		options root=$ROOT_ID ${LUKS_DEV}${RESUME}rw net.ifnames=0$([[ $BTRFS_MNT ]] && printf ' %s' "$BTRFS_MNT")
	EOF

	mkdir -pv "$MNT/etc/pacman.d/hooks"

	cat >"$MNT/etc/pacman.d/hooks/systemd-boot.hook" <<-EOF
		[Trigger]
		Type = Package
		Operation = Upgrade
		Target = systemd

		[Action]
		Description = Updating systemd-boot
		When = PostTransaction
		Exec = /usr/bin/bootctl update
	EOF
	return 0
}

###############################################################################
# btrfs functions

btrfs_name() {
	local txt="$1"
	local exists="$2"

	SUBVOL=''
	until [[ $SUBVOL ]]; do
		dlg SUBVOL input "Subvolume Name" "$txt" || return 1
		if [[ -z $SUBVOL ]]; then
			return 1
		elif [[ $SUBVOL =~ \ |\' || $exists == *"$SUBVOL"* ]]; then
			msg "Subvolume Name Error" "$_errvolname"
			SUBVOL=''
		fi
	done
	return 0
}

btrfs_mount() {
	local part="$1"
	local mntp="$2"
	local subvol="$3"

	[[ $mntp == "$MNT" ]] && BTRFS_MNT="rootflags=subvol=$subvol"
	mount_opts "$part" 'btrfs' && [[ $MNT_OPTS ]] && MNT_OPTS+=','
	mount -o ${MNT_OPTS}subvol="$subvol" "$part" "$mntp" 2>"$ERR"
	errshow 0 "mount -o ${MNT_OPTS}subvol=$subvol $part $mntp" || return 1
	msg "Mount Complete" "\nMounted $part subvol=$subvol at $mntp\n" 1
}

btrfs_subvols() {
	local part="$1"
	local mntp="${MNT}$2"
	local mvol=''

	btrfs_name "\nEnter a name for the initial subvolume on $part e.g. 'subvol_root'." || return 1
	mvol="$SUBVOL"
	btrfs subvolume create "$mntp/$mvol" >/dev/null 2>"$ERR"
	errshow 0 "btrfs subvolume create $mntp/$mvol" || return 1

	umount_dir "$mntp" || return 1
	btrfs_mount "$part" "$mntp" "$mvol" || return 1

	btrfs_extsubvols "$mntp" "$mvol" || return 1
	msg "Btrfs Complete" "\nSubvolume(s) created successfully.\n"
}

btrfs_extsubvols() {
	local mntp="$1"
	local mvol="$2"
	local list=''
	local n=0

	SUBVOL_COUNT=0
	dlg SUBVOL_COUNT menu "Subvolume Count" "\nSelect the number of subvolumes to create in: $mvol" \
		0 - 1 - 2 - 3 - 4 - 5 - 6 - 7 - 8 - 9 -
	while ((++n <= SUBVOL_COUNT)); do
		local txt="\nEnter a name for subvolume $n within '$mvol'."
		if ((n > 1)); then
			btrfs_name "$txt\n\nCreated subvolumes: $list" "$list $mvol" || return 1
		else
			btrfs_name "$txt" "$mvol" || return 1
		fi
		btrfs subvolume create "$mntp/$SUBVOL" >/dev/null 2>"$ERR"
		errshow 0 "btrfs subvolume create $mntp/$SUBVOL" || return 1
		list+="$SUBVOL "
	done
	return 0
}

###############################################################################
# lvm functions

lvm_menu() {
	is_bg_install || return 1
	lvm_detect
	local choice
	while :; do
		dlg choice menu "Logical Volume Management" "$_lvmmenu" \
			'create' "Create a new volume group and volume(s)" \
			'remove' "Delete an existing volume group" \
			'remove_all' "Delete ALL volume groups and volume(s)" \
			"back" "Return to the device management menu"
		case "$choice" in
		'create') lvm_create && break ;;
		'remove') lvm_del_one && yesno "Remove Volume Group" "$_lvmdelask" && vgremove -f "$DEL_VG" >/dev/null 2>&1 ;;
		'remove_all') lvm_del_all ;;
		*) break ;;
		esac
	done
	return 0
}

lvm_detect() {
	if [[ $(vgs -o vg_name --noheading 2>/dev/null) ]]; then
		if [[ $(lvs -o vg_name,lv_name --noheading --separator - 2>/dev/null) && $(pvs -o pv_name --noheading 2>/dev/null) ]]; then
			msg "LVM Setup" "\nActivating existing logical volume management.\n" 0
			modprobe dm-mod >/dev/null 2>"$ERR"
			errshow 0 'modprobe dm-mod > /dev/null'
			vgscan >/dev/null 2>&1
			vgchange -ay >/dev/null 2>&1
		fi
	fi
}

lvm_create() {
	VGROUP='' LVM_PARTS='' VOL_COUNT=0 VGROUP_MB=0
	umount_dir "$MNT"
	lvm_mkgroup || return 1

	local txt="\nThe last (or only) logical volume will automatically use all remaining space in the volume group."
	dlg VOL_COUNT menu "Create Volume Group" "\nSelect the number of logical volumes (LVs) to create in: $VGROUP\n$txt" \
		1 - 2 - 3 - 4 - 5 - 6 - 7 - 8 - 9 - 10 -
	[[ $VOL_COUNT ]] || return 1
	lvm_extra_lvs || return 1

	lvm_volume_name "$_lvmlvname\nNOTE: This LV will use up all remaining space in the volume group (${VGROUP_MB}MB)" || return 1
	msg "Create Volume Group (LV:$VOL_COUNT)" "\nCreating volume $VNAME from remaining space in $VGROUP\n" 0
	lvcreate -l +100%FREE "$VGROUP" -n "$VNAME" >/dev/null 2>"$ERR"
	errshow 0 "lvcreate -l +100%FREE $VGROUP -n $VNAME" || return 1

	LVM='logical volume'
	sleep 0.5
	txt="\nDone, volume: $VGROUP-$VNAME (${VOLUME_SIZE:-${VGROUP_MB}MB}) has been created.\n"
	msg "Create Volume Group (LV:$VOL_COUNT)" "$txt\n$(lsblk -o NAME,SIZE $LVM_PARTS)\n"
	return 0
}

lvm_lv_size() {
	local txt="${VGROUP}: ${SIZE}$SIZE_UNIT (${VGROUP_MB}MB remaining).$_lvmlvsize"

	while :; do
		ERR_SIZE=0
		dlg VOLUME_SIZE input "Create Volume Group (LV:$VOL_COUNT)" "$txt"
		if [[ -z $VOLUME_SIZE ]]; then
			ERR_SIZE=1
			break # allow bailing with escape or an empty choice
		elif ((!${VOLUME_SIZE:0:1})); then
			ERR_SIZE=1 # size values can't begin with '0'
		else
			# walk the string and make sure all but the last char are digits
			local lv=$((${#VOLUME_SIZE} - 1))
			for ((i = 0; i < lv; i++)); do
				[[ ${VOLUME_SIZE:$i:1} =~ [0-9] ]] || {
					ERR_SIZE=1
					break
				}
			done
			if ((ERR_SIZE != 1)); then
				case ${VOLUME_SIZE:$lv:1} in
				[mMgG])
					local s=${VOLUME_SIZE:0:$lv} m=$((s * 1000))
					case ${VOLUME_SIZE:$lv:1} in
					[Gg])
						if ((m >= VGROUP_MB)); then
							ERR_SIZE=1
						else
							VGROUP_MB=$((VGROUP_MB - m))
						fi
						;;
					[Mm])
						if ((${VOLUME_SIZE:0:$lv} >= VGROUP_MB)); then
							ERR_SIZE=1
						else
							VGROUP_MB=$((VGROUP_MB - s))
						fi
						;;
					*) ERR_SIZE=1 ;;
					esac
					;;
				*) ERR_SIZE=1 ;;
				esac
			fi
		fi
		((ERR_SIZE)) || break
		msg "Invalid Logical Volume Size" "$_lvmerrlvsize" 2
	done

	return $ERR_SIZE
}

lvm_mkgroup() {
	local named=''

	until [[ $named ]]; do
		lvm_partitions || return 1
		lvm_group_name || return 1
		yesno "Create Volume Group" "\nCreate volume group: $VGROUP\n\nusing these partition(s): $LVM_PARTS\n" && named=true
	done

	msg "Create Volume Group" "\nCreating volume group: $VGROUP\n" 0
	vgcreate -f "$VGROUP" $LVM_PARTS >/dev/null 2>"$ERR"
	errshow 0 "vgcreate -f '$VGROUP' $LVM_PARTS >/dev/null" || return 1

	SIZE=$(vgdisplay "$VGROUP" | awk '/VG Size/ { gsub(/[^0-9.]/, ""); print int($0) }')
	SIZE_UNIT="$(vgdisplay "$VGROUP" | awk '/VG Size/ { print substr($NF, 0, 1) }')"

	if [[ $SIZE_UNIT == 'G' ]]; then
		VGROUP_MB=$((SIZE * 1000))
	else
		VGROUP_MB=$SIZE
	fi

	msg "Create Volume Group" "\nVolume group $VGROUP (${SIZE}$SIZE_UNIT) successfully created\n" 2
}

lvm_del_all() {
	local v pv
	pv="$(pvs -o pv_name --noheading 2>/dev/null)"
	v="$(lvs -o vg_name,lv_name --noheading --separator - 2>/dev/null)"
	VGROUP="$(vgs -o vg_name --noheading 2>/dev/null)"

	if [[ $VGROUP || $v || $pv ]]; then
		if yesno "Remove All Volume Groups" "$_lvmdelask"; then
			for i in $v; do lvremove -f "/dev/mapper/$i" >/dev/null 2>&1; done
			for i in $VGROUP; do vgremove -f "$i" >/dev/null 2>&1; done
			for i in $pv; do pvremove -f "$i" >/dev/null 2>&1; done
			LVM=''
		fi
		for i in $(lvmdiskscan | grep 'LVM physical volume' | grep 'sd[a-z]' | sed 's/\/dev\///' | awk '{print $1}'); do
			dd if=/dev/zero bs=512 count=512 of=/dev/${i} >/dev/null 2>&1
		done
	else
		msg "Delete LVM" "\nNo available LVM to remove...\n" 2
		LVM=''
	fi
}

lvm_del_one() {
	DEL_VG=''
	VOL_GROUP_LIST=''

	for i in $(lvs --noheadings | awk '{print $2}' | sort | uniq); do
		VOL_GROUP_LIST+="$i $(vgdisplay "$i" | awk '/VG Size/ {print $3$4}') "
	done

	[[ $VOL_GROUP_LIST ]] || {
		msg "No Groups" "\nNo volume groups found."
		return 1
	}

	dlg DEL_VG menu "Logical Volume Management" "\nSelect volume group to delete.\n\nAll logical volumes within will also be deleted." $VOL_GROUP_LIST
	[[ $DEL_VG ]]
}

lvm_extra_lvs() {
	while ((VOL_COUNT > 1)); do
		lvm_volume_name "$_lvmlvname" || return 1
		lvm_lv_size || return 1

		msg "Create Volume Group (LV:$VOL_COUNT)" "\nCreating a $VOLUME_SIZE volume $VNAME in $VGROUP\n" 0
		lvcreate -L "$VOLUME_SIZE" "$VGROUP" -n "$VNAME" >/dev/null 2>"$ERR"
		errshow 0 "lvcreate -L '$VOLUME_SIZE' '$VGROUP' -n '$VNAME'" || return 1

		msg "Create Volume Group (LV:$VOL_COUNT)" "\nDone, logical volume (LV) $VNAME ($VOLUME_SIZE) has been created.\n"
		((VOL_COUNT--))
	done
	return 0
}

lvm_partitions() {
	part_find 'part|crypt' || return 1
	PARTS="$(awk 'NF > 0 {print $0 " off"}' <<<"$PARTS")"
	[[ $LUKS && $LUKS_PART ]] && part_countdec $LUKS_PART
	dlg LVM_PARTS check "Create Volume Group" "\nSelect the partition(s) to use for the physical volume (PV)." $PARTS
}

lvm_group_name() {
	VGROUP=''
	until [[ $VGROUP ]]; do
		dlg VGROUP input "Create Volume Group" "$_lvmvgname"
		if [[ -z $VGROUP ]]; then
			return 1
		elif [[ ${VGROUP:0:1} == "/" || $VGROUP =~ \ |\' ]] || vgdisplay | grep -q "$VGROUP"; then
			msg "LVM Name Error" "$_errvolname"
			VGROUP=''
		fi
	done
	return 0
}

lvm_volume_name() {
	VNAME=''
	local txt="$1"
	until [[ $VNAME ]]; do
		dlg VNAME input "Create Volume Group (LV:$VOL_COUNT)" "\n$txt"
		if [[ -z $VNAME ]]; then
			return 1
		elif [[ ${VNAME:0:1} == "/" || $VNAME =~ \ |\' ]] || lsblk | grep -q "$VNAME"; then
			msg "LVM Name Error" "$_errvolname"
			VNAME=''
		fi
	done
	return 0
}

###############################################################################
# luks functions

luks_menu() {
	local choice
	is_bg_install || return 1
	while :; do
		dlg choice menu 'LUKS Encryption' "$_luksmenu" \
			'basic' 'LUKS setup with default settings' \
			'open' 'Open an existing LUKS partition' \
			'advanced' 'Specify cypher type and other flags for cryptsetup' \
			'back' 'Return to the device management menu'
		case "$choice" in
		'basic') luks_basic || return 1 ;;
		'open') luks_open || return 1 ;;
		'advanced') luks_advanced || return 1 ;;
		*) break ;;
		esac
	done
	return 0
}

luks_open() {
	modprobe -a dm-mod dm_crypt >/dev/null 2>&1
	umount_dir "$MNT"
	part_find 'part|crypt|lvm' || return 1

	if ((PART_COUNT == 1)); then
		LUKS_PART="$(awk 'NF > 0 {print $1}' <<<"$PARTS")"
	else
		[[ $LVM && $LVM_PARTS ]] && part_countdec $LVM_PARTS
		dlg LUKS_PART menu "LUKS Open" "\nSelect which partition to open." $PARTS
	fi

	[[ $LUKS_PART ]] || return 1

	luks_pass "LUKS Open" || return 1
	msg "LUKS Open" "\nOpening encryption: $LUKS_NAME\n\nUsing device/volume: $(part_pretty "$LUKS_PART")\n" 0
	cryptsetup open --type luks "$LUKS_PART" "$LUKS_NAME" <<<"$LUKS_PASS" 2>"$ERR"
	errshow 0 "cryptsetup open --type luks '$LUKS_PART' '$LUKS_NAME' <<< '$LUKS_PASS'" || return 1
	LUKS='encrypted'
	luks_show
	return 0
}

luks_pass() {
	LUKS_PASS=''
	local t="$1"
	typeset -a ans=(cryptroot) # default name to start

	until [[ $LUKS_PASS ]]; do
		tput cnorm
		dialog --insecure --backtitle "$DIST - $SYS - v$VER" \
			--separator $'\n' --title " $t " --mixedform "$_luksomenu" 0 0 0 \
			"Name:" 1 1 "${ans[0]}" 1 7 "$COLUMNS" 0 0 \
			"Password:" 2 1 '' 2 11 "$COLUMNS" 0 1 \
			"Password2:" 3 1 '' 3 12 "$COLUMNS" 0 1 2>"$ANS" || return 1

		mapfile -t ans <"$ANS"

		if [[ -z "${ans[0]}" ]]; then
			msg "Name Empty" "\nEncrypted device name cannot be empty.\n\nPlease try again.\n" 2
		elif [[ -z "${ans[1]}" || "${ans[1]}" != "${ans[2]}" ]]; then
			LUKS_NAME="${ans[0]}"
			msg "Password Mismatch" "\nThe passwords entered do not match.\n\nPlease try again.\n" 2
		else
			LUKS_NAME="${ans[0]}"
			LUKS_PASS="${ans[1]}"
		fi
	done

	return 0
}

luks_show() {
	sleep 0.5
	msg "LUKS Encryption" "\nEncrypted partition ready for mounting.\n\n$(lsblk -o NAME,SIZE,FSTYPE "$LUKS_PART")\n\n"
}

luks_setup() {
	modprobe -a dm-mod dm_crypt >/dev/null 2>&1
	umount_dir "$MNT"
	part_find 'part|lvm' || return 1

	if [[ $AUTO_ROOT ]]; then
		LUKS_PART="$AUTO_ROOT"
	elif ((PART_COUNT == 1)); then
		LUKS_PART="$(awk 'NF > 0 {print $1}' <<<"$PARTS")"
	else
		[[ $LVM && $LVM_PARTS ]] && part_countdec $LVM_PARTS
		dlg LUKS_PART menu "LUKS Encryption" "\nSelect the partition you want to encrypt." $PARTS
	fi

	[[ $LUKS_PART ]] || return 1
	luks_pass "LUKS Encryption"
}

luks_basic() {
	luks_setup || return 1
	msg "LUKS Encryption" "\nCreating encrypted partition: $LUKS_NAME\n\nDevice or volume used: $LUKS_PART\n" 0
	cryptsetup -q luksFormat "$LUKS_PART" <<<"$LUKS_PASS" 2>"$ERR"
	errshow 0 "cryptsetup -q luksFormat '$LUKS_PART' <<< '$LUKS_PASS'" || return 1
	cryptsetup open "$LUKS_PART" "$LUKS_NAME" <<<"$LUKS_PASS" 2>"$ERR"
	errshow 0 "cryptsetup open '$LUKS_PART' '$LUKS_NAME' <<< '$LUKS_PASS'" || return 1
	LUKS='encrypted'
	luks_show
	return 0
}

luks_advanced() {
	luks_setup || return 1
	local cipher
	dlg cipher input "LUKS Encryption" "$_lukskey" "-s 512 -c aes-xts-plain64"
	[[ $cipher ]] || return 1
	msg "LUKS Encryption" "\nCreating encrypted partition: $LUKS_NAME\n\nDevice or volume used: $LUKS_PART\n" 0
	cryptsetup -q $cipher luksFormat "$LUKS_PART" <<<"$LUKS_PASS" 2>"$ERR"
	errshow 0 "cryptsetup -q $cipher luksFormat '$LUKS_PART' <<< '$LUKS_PASS'" || return 1
	cryptsetup open "$LUKS_PART" "$LUKS_NAME" <<<"$LUKS_PASS" 2>"$ERR"
	errshow 0 "cryptsetup open '$LUKS_PART' '$LUKS_NAME' <<< '$LUKS_PASS'" || return 1
	LUKS='encrypted'
	luks_show
	return 0
}

###############################################################################
# simple functions
# some help avoid repetition and improve usability of some commands
# others are initial setup functions used before reaching the main loop

ofn() {
	[[ "$2" == *"$1"* ]] && printf "on" || printf "off"
}

die() {
	# exit cleanly with exit code $1 or the last command's exit code
	# when $1 == 127 we unmount and reboot
	local e="$1"
	e="${e:-$?}"

	trap - INT
	tput cnorm
	((!e)) && clear
	if [[ -d $MNT ]]; then
		umount_dir "$MNT"
		((e == 127)) && umount_dir /run/archiso/bootmnt && sleep 0.5 && reboot -f
	fi
	exit $e
}

dlg() {
	local var="$1"   # assign output from dialog to var
	local dlg_t="$2" # dialog type (menu, check, input)
	local title="$3" # dialog title
	local body="$4"  # dialog message
	local n=0        # number of items to display for menu and check dialogs

	shift 4 # shift off args assigned above

	# adjust n when passed a large list
	local l=$((LINES - 20))
	((($# / 2) > l)) && n=$l

	case "$dlg_t" in
	menu)
		tput civis
		dialog --backtitle "$DIST - $SYS - v$VER" --title " $title " \
			--menu "$body" 0 0 $n "$@" 2>"$ANS" || {
			tput cnorm
			return 1
		}
		;;
	check)
		tput civis
		dialog --backtitle "$DIST - $SYS - v$VER" --title " $title " \
			--checklist "$body" 0 0 $n "$@" 2>"$ANS" || {
			tput cnorm
			return 1
		}
		;;
	input)
		tput cnorm
		if [[ $1 && $1 != 'limit' ]]; then
			local def="$1" # assign default value for input
			shift
		fi
		if [[ $1 == 'limit' ]]; then
			dialog --backtitle "$DIST - $SYS - v$VER" --max-input 63 \
				--title " $title " --inputbox "$body" 0 0 "$def" 2>"$ANS" || return 1
		else
			dialog --backtitle "$DIST - $SYS - v$VER" --title " $title " \
				--inputbox "$body" 0 0 "$def" 2>"$ANS" || return 1
		fi
		;;
	esac
	# if answer file isn't empty read from it into $var
	[[ -s "$ANS" ]] && printf -v "$var" "%s" "$(<"$ANS")"
}

msg() {
	# displays a message dialog
	# when more than 2 args the message will disappear after sleep time ($3)
	local title="$1"
	local body="$2"
	shift 2
	tput civis
	if (($#)); then
		dialog --backtitle "$DIST - $SYS - v$VER" --sleep "$1" --title " $title " --infobox "$body\n" 0 0
	else
		dialog --backtitle "$DIST - $SYS - v$VER" --title " $title " --msgbox "$body\n" 0 0
	fi
}

usage() {
	cat <<-EOF
		usage: $1 [-cfhDn] [-r ROOT] [-b BOOT] [-d DISTRO] [-m MOUNTPOINT]

		options:
		    -h  print this message and exit
		    -f  skip setting the font size
		    -D  enable xtrace and log output to $DBG
		    -c  disable network connection tests
		    -m  set the mountpoint used for the new installation
		    -d  set the distribution name for the installed system
		    -n  no partitioning, mounting, or formatting (self mount)
		    -r  root partition to use for install, required when using -n
		    -b  boot partition to use for install, required on UEFI systems when using -n

	EOF
	exit 0
}

yesno() {
	local title="$1"
	local body="$2"
	local yes='Yes'
	local no='No'
	(($# >= 3)) && yes="$3"
	(($# >= 4)) && no="$4"
	tput civis
	if (($# == 5)); then
		dialog --backtitle "$DIST - $SYS - v$VER" --defaultno \
			--title " $title " --yes-label "$yes" --no-label "$no" --yesno "$body\n" 0 0
	else
		dialog --backtitle "$DIST - $SYS - v$VER" --title " $title " \
			--yes-label "$yes" --no-label "$no" --yesno "$body\n" 0 0
	fi
}

chrun() {
	arch-chroot "$MNT" bash -c "$1"
}

zshrc() {
	cat >"$MNT/etc/skel/.zshrc" <<-EOF
		if [[ \$- != *i* ]]; then
			    return
		fi

		# completion cache path setup
		typeset -g comppath="\$HOME/.cache"
		typeset -g compfile="\$comppath/.zcompdump"

		if [[ -d "\$comppath" ]]; then
			    [[ -w "\$compfile" ]] || rm -rf "\$compfile" >/dev/null 2>&1
		else
			    mkdir -p "\$comppath"
		fi

		# zsh internal stuff
		SHELL=\$(which zsh || echo '/bin/zsh')
		KEYTIMEOUT=1
		SAVEHIST=10000
		HISTSIZE=10000
		HISTFILE="\$HOME/.cache/.zsh_history"

		alias la='ls -Ah'
		alias ll='ls -lAh'
		alias grep='grep --color=auto'
		alias grub-update='sudo grub-mkconfig -o /boot/grub/grub.cfg'
		alias mirror-update='sudo reflector --verbose --connection-timeout 2 --threads 10 --latest 200 --age 24 --score 75 --sort rate --fastest 6 --save /etc/pacman.d/mirrorlist'

		cd() # cd and ls after
		{
			    builtin cd "\$@" && command ls --color=auto -F
		}

		src() # recompile completion and reload zsh
		{
			    autoload -U zrecompile
			    rm -rf "\$compfile"*
			    compinit -u -d "\$compfile"
			    zrecompile -p "\$compfile"
			    exec zsh
		}

		# less/manpager colours
		export MANWIDTH=80
		export LESS='-R'
		export LESSHISTFILE=-
		export LESS_TERMCAP_me=$'\\e[0m'
		export LESS_TERMCAP_se=$'\\e[0m'
		export LESS_TERMCAP_ue=$'\\e[0m'
		export LESS_TERMCAP_us=$'\\e[32m'
		export LESS_TERMCAP_mb=$'\\e[31m'
		export LESS_TERMCAP_md=$'\\e[31m'
		export LESS_TERMCAP_so=$'\\e[47;30m'
		export LESSPROMPT='?f%f .?ltLine %lt:?pt%pt\%:?btByte %bt:-...'

		# completion
		setopt CORRECT
		setopt NO_NOMATCH
		setopt LIST_PACKED
		setopt ALWAYS_TO_END
		setopt GLOB_COMPLETE
		setopt COMPLETE_ALIASES
		setopt COMPLETE_IN_WORD

		# builtin command behaviour
		setopt AUTO_CD

		# job control
		setopt AUTO_CONTINUE
		setopt LONG_LIST_JOBS

		# history control
		setopt HIST_VERIFY
		setopt SHARE_HISTORY
		setopt HIST_IGNORE_SPACE
		setopt HIST_SAVE_NO_DUPS
		setopt HIST_IGNORE_ALL_DUPS

		# misc
		setopt EXTENDED_GLOB
		setopt TRANSIENT_RPROMPT
		setopt INTERACTIVE_COMMENTS


		autoload -U compinit     # completion
		autoload -U terminfo     # terminfo keys
		zmodload -i zsh/complist # menu completion
		autoload -U promptinit   # prompt

		# better history navigation, matching currently typed text
		autoload -U up-line-or-beginning-search; zle -N up-line-or-beginning-search
		autoload -U down-line-or-beginning-search; zle -N down-line-or-beginning-search

		# set the terminal mode when entering or exiting zle, otherwise terminfo keys are not loaded
		if (( \${+terminfo[smkx]} && \${+terminfo[rmkx]} )); then
			    zle-line-init() { echoti smkx; }; zle -N zle-line-init
			    zle-line-finish() { echoti rmkx; }; zle -N zle-line-finish
		fi

		exp_alias() # expand aliases to the left (if any) before inserting the key pressed
		{
			    zle _expand_alias
			    zle self-insert
		}; zle -N exp_alias

		# bind keys not in terminfo
		bindkey -- ' '     exp_alias
		bindkey -- '^P'    up-history
		bindkey -- '^N'    down-history
		bindkey -- '^E'    end-of-line
		bindkey -- '^A'    beginning-of-line
		bindkey -- '^[^M'  self-insert-unmeta # alt-enter to insert a newline/carriage return
		bindkey -- '^[05M' accept-line # fix for enter key on some systems

		# default shell behaviour using terminfo keys
		[[ -n \${terminfo[kdch1]} ]] && bindkey -- "\${terminfo[kdch1]}" delete-char                   # delete
		[[ -n \${terminfo[kend]}  ]] && bindkey -- "\${terminfo[kend]}"  end-of-line                   # end
		[[ -n \${terminfo[kcuf1]} ]] && bindkey -- "\${terminfo[kcuf1]}" forward-char                  # right arrow
		[[ -n \${terminfo[kcub1]} ]] && bindkey -- "\${terminfo[kcub1]}" backward-char                 # left arrow
		[[ -n \${terminfo[kich1]} ]] && bindkey -- "\${terminfo[kich1]}" overwrite-mode                # insert
		[[ -n \${terminfo[khome]} ]] && bindkey -- "\${terminfo[khome]}" beginning-of-line             # home
		[[ -n \${terminfo[kbs]}   ]] && bindkey -- "\${terminfo[kbs]}"   backward-delete-char          # backspace
		[[ -n \${terminfo[kcbt]}  ]] && bindkey -- "\${terminfo[kcbt]}"  reverse-menu-complete         # shift-tab
		[[ -n \${terminfo[kcuu1]} ]] && bindkey -- "\${terminfo[kcuu1]}" up-line-or-beginning-search   # up arrow
		[[ -n \${terminfo[kcud1]} ]] && bindkey -- "\${terminfo[kcud1]}" down-line-or-beginning-search # down arrow

		# correction
		zstyle ':completion:*:correct:*' original true
		zstyle ':completion:*:correct:*' insert-unambiguous true
		zstyle ':completion:*:approximate:*' max-errors 'reply=(\$(( (\$#PREFIX + \$#SUFFIX) / 3 )) numeric)'

		# completion
		zstyle ':completion:*' use-cache on
		zstyle ':completion:*' cache-path "\$comppath"
		zstyle ':completion:*' rehash true
		zstyle ':completion:*' verbose true
		zstyle ':completion:*' insert-tab false
		zstyle ':completion:*' accept-exact '*(N)'
		zstyle ':completion:*' squeeze-slashes true
		zstyle ':completion:*:*:*:*:*' menu select
		zstyle ':completion:*:match:*' original only
		zstyle ':completion:*:-command-:*:' verbose false
		zstyle ':completion::complete:*' gain-privileges 1
		zstyle ':completion:*:manuals.*' insert-sections true
		zstyle ':completion:*:manuals' separate-sections true
		zstyle ':completion:*' completer _complete _match _approximate _ignored
		zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
		zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories

		# labels and categories
		zstyle ':completion:*' group-name ''
		zstyle ':completion:*:matches' group 'yes'
		zstyle ':completion:*:options' description 'yes'
		zstyle ':completion:*:options' auto-description '%d'
		zstyle ':completion:*:default' list-prompt '%S%M matches%s'
		zstyle ':completion:*' format ' %F{green}->%F{yellow} %d%f'
		zstyle ':completion:*:messages' format ' %F{green}->%F{purple} %d%f'
		zstyle ':completion:*:descriptions' format ' %F{green}->%F{yellow} %d%f'
		zstyle ':completion:*:warnings' format ' %F{green}->%F{red} no matches%f'
		zstyle ':completion:*:corrections' format ' %F{green}->%F{green} %d: %e%f'

		# menu colours
		eval "\$(dircolors)"
		zstyle ':completion:*' list-colors \${(s.:.)LS_COLORS}
		zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=36=0=01'

		# command parameters
		zstyle ':completion:*:functions' ignored-patterns '(prompt*|_*|*precmd*|*preexec*)'
		zstyle ':completion::*:(-command-|export):*' fake-parameters \${\${\${_comps[(I)-value-*]#*,}%%,*}:#-*-}
		zstyle ':completion:*:*:*:*:processes' command "ps -u \$USER -o pid,user,comm -w -w"
		zstyle ':completion:*:processes-names' command 'ps c -u \${USER} -o command | uniq'
		zstyle ':completion:*:(vim|nvim|vi|nano):*' ignored-patterns '*.(wav|mp3|flac|ogg|mp4|avi|mkv|iso|so|o|7z|zip|tar|gz|bz2|rar|deb|pkg|gzip|pdf|png|jpeg|jpg|gif)'

		# hostnames and addresses
		zstyle ':completion:*:ssh:*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
		zstyle ':completion:*:ssh:*' group-order users hosts-domain hosts-host users hosts-ipaddr
		zstyle ':completion:*:(scp|rsync):*' tag-order 'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
		zstyle ':completion:*:(scp|rsync):*' group-order users files all-files hosts-domain hosts-host hosts-ipaddr
		zstyle ':completion:*:(ssh|scp|rsync):*:hosts-host' ignored-patterns '*(.|:)*' loopback ip6-loopback localhost ip6-localhost broadcasthost
		zstyle ':completion:*:(ssh|scp|rsync):*:hosts-domain' ignored-patterns '<->.<->.<->.<->' '^[-[:alnum:]]##(.[-[:alnum:]]##)##' '*@*'
		zstyle ':completion:*:(ssh|scp|rsync):*:hosts-ipaddr' ignored-patterns '^(<->.<->.<->.<->|(|::)([[:xdigit:].]##:(#c,2))##(|%*))' '127.0.0.<->' '255.255.255.255' '::1' 'fe80::*'
		zstyle -e ':completion:*:hosts' hosts 'reply=( \${=\${=\${=\${\${(f)"\$(cat {/etc/ssh_,~/.ssh/known_}hosts(|2)(N) 2>/dev/null)"}%%[#| ]*}//\]:[0-9]*/ }//,/ }//\[/ } \${=\${(f)"\$(cat /etc/hosts(|)(N) <<(ypcat hosts 2>/dev/null))"}%%\#*} \${=\${\${\${\${(@M)\${(f)"\$(cat ~/.ssh/config 2>/dev/null)"}:#Host *}#Host }:#*\**}:#*\?*}})'
		ttyctl -f

		# initialize completion
		compinit -u -d "\$compfile"

		# initialize prompt with a decent built-in theme
		promptinit
		prompt adam1
	EOF
}

debug() {
	export PS4='| installer: LN:${LINENO} FN:${FUNCNAME[0]:+ ${FUNCNAME[0]}()} ->  '
	set -x
	exec 3>|$DBG
	BASH_XTRACEFD=3
	DEBUG=true
}

errmsg() {
	local err=""

	err="$(sed 's/[^[:print:]]//g; s/\[[0-9\;:]*\?m//g; s/==> //g; s/] ERROR:/]\nERROR:/g' "$ERR")"
	[[ -z $err ]] && err="no error message was output"
	printf "%s" "$err"
}

termcol() {
	local colors=(
		"\e]P0191919" # #191919
		"\e]P1D15355" # #D15355
		"\e]P2609960" # #609960
		"\e]P3FFCC66" # #FFCC66
		"\e]P4255A9B" # #255A9B
		"\e]P5AF86C8" # #AF86C8
		"\e]P62EC8D3" # #2EC8D3
		"\e]P7949494" # #949494
		"\e]P8191919" # #191919
		"\e]P9D15355" # #D15355
		"\e]PA609960" # #609960
		"\e]PBFF9157" # #FF9157
		"\e]PC4E88CF" # #4E88CF
		"\e]PDAF86C8" # #AF86C8
		"\e]PE2ec8d3" # #2ec8d3
		"\e]PFE1E1E1" # #E1E1E1
	)

	[[ $TERM == 'linux' ]] && printf "%b" "${colors[@]}" && clear
}

errshow() {
	# shellcheck disable=SC2181
	[ $? -eq 0 ] && return 0

	local fatal=$1
	shift 1 # always shift off the fatal level arg
	local cmd="$1"

	if [[ $cmd == *chrun* ]]; then
		local cmd="arch-chroot $MNT bash -c ${cmd##chrun }"
	fi

	local txt
	txt="\nCommand: $cmd\n\n$(errmsg)\n\n"
	tput cnorm

	if ((fatal)); then
		read -re -p $'\nAn error occurred.. Press [Enter] when ready to continue to error dialog'
		dialog --backtitle "$DIST - $SYS - v$VER" --title " Install Error " --yes-label "Abort" --no-label "Continue" \
			--yesno "${txt}Errors at this stage must be fixed before the install can continue.\n$_errchoice\n" 0 0 || return 0
		[[ -r $DBG && $TERM == 'linux' ]] && less "$DBG"
		die 1
	fi
	dialog --backtitle "$DIST - $SYS - v$VER" --title " Install Error " --yes-label "Abort" --no-label "Continue" \
		--yesno "${txt}Errors at this stage may not be serious depending on the command and error type.\n$_errchoice\n" 0 0 || return 0

	tput civis
	return 1
}

prechecks() {
	# check whether we have all steps done for a given level ($1)
	# if a fail is encountered we display an error dialog and set
	# the selected entry number ($SEL) back to the step required to progress
	local i=1

	if (($1 >= 1)) && ! grep -q " $MNT " /proc/mounts; then
		msg "Not Mounted" "\nPartition(s) must be mounted first.\n" 2
		if [[ $NOMOUNT ]]; then
			die 1
		else
			SEL=1
		fi
		i=0
	elif [[ $1 -ge 2 && (-z $NEWUSER || -z $USER_PASS) ]]; then
		msg "No User" "\nA user must be created first.\n" 2
		if [[ $NOMOUNT ]]; then
			SEL=0
		else
			SEL=2
		fi
		i=0
	elif [[ $1 -ge 3 && -z $CONFIG_DONE ]]; then
		msg "No Config" "\nSystem configuration must be done first.\n" 2
		if [[ $NOMOUNT ]]; then
			SEL=1
		else
			SEL=3
		fi
		i=0
	fi
	((i)) # return code
}

umount_dir() {
	mount | grep -q 'swap' && swapoff -a
	for dir; do
		if [[ -d $dir ]] && grep -q " $dir " /proc/mounts; then
			if ! umount "$dir" 2>/dev/null; then
				sleep 0.5
				umount -f "$dir" 2>/dev/null || umount -l "$dir"
			fi
		fi
	done
}

dialog_cfg() {
	[[ -f /etc/dialogrc ]] && return
	cat >/etc/dialogrc <<-EOF
		#
		# Run-time configuration file for dialog
		#
		# Types of values:
		#
		# Number     -  <number>
		# String     -  "string"
		# Boolean    -  <ON|OFF>
		# Attribute  -  (foreground,background,highlight?)

		aspect = 25

		separate_widget = ""

		tab_len = 0

		visit_items = OFF

		use_shadow = ON
		use_colors = ON

		screen_color = (CYAN,BLACK,ON)

		shadow_color = (BLACK,BLACK,ON)

		dialog_color = (WHITE,BLACK,ON)

		title_color = (RED,BLACK,ON)

		border_color = (WHITE,BLACK,ON)
		border2_color = border_color

		button_active_color = (BLACK,WHITE,ON)
		button_inactive_color = (WHITE,BLACK,ON)

		button_key_active_color = (BLACK,WHITE,ON)
		button_key_inactive_color = (RED,BLACK,ON)

		button_label_active_color = (BLACK,WHITE,ON)
		button_label_inactive_color = (WHITE,BLACK,ON)

		inputbox_color = (WHITE,BLACK,ON)

		inputbox_border_color = (WHITE,BLACK,ON)
		inputbox_border2_color = inputbox_border_color

		searchbox_color = (WHITE,BLACK,ON)
		searchbox_title_color = (RED,BLACK,ON)

		searchbox_border_color = (WHITE,BLACK,ON)
		searchbox_border2_color = searchbox_border_color

		position_indicator_color = (GREEN,BLACK,ON)

		menubox_color = (WHITE,BLACK,ON)

		gauge_color = (WHITE,BLACK,ON)

		menubox_border_color = (WHITE,BLACK,ON)
		menubox_border2_color = menubox_border_color

		item_color = (WHITE,BLACK,ON)
		item_selected_color = (BLACK,WHITE,ON)

		tag_color = (WHITE,BLACK,ON)
		tag_selected_color = (BLACK,WHITE,ON)

		tag_key_color = (RED,BLACK,ON)
		tag_key_selected_color = (BLACK,WHITE,ON)

		check_color = (WHITE,BLACK,ON)
		check_selected_color = (BLACK,WHITE,ON)

		uarrow_color = (GREEN,BLACK,ON)
		darrow_color = (GREEN,BLACK,ON)

		itemhelp_color = (BLACK,WHITE,ON)

		form_text_color = (WHITE,BLACK,ON)
		form_active_text_color = (BLACK,WHITE,ON)
		form_item_readonly_color = (WHITE,BLACK,ON)

		bindkey formfield TAB  form_NEXT
		bindkey formbox   TAB  form_NEXT
		bindkey formfield BTAB form_prev
		bindkey formbox   BTAB form_prev
	EOF
}

chk_connect() {
	if [[ ! -f /tmp/new ]]; then
		msg "Network Connect" "\nVerifying network connection\n" 0
		if [[ $VIRT != 'none' ]] && hash nm-online >/dev/null 2>&1 && [[ $(systemctl is-active NetworkManager.service) == "active" ]]; then
			nm-online >/dev/null 2>&1
		else
			ping -qc1 'archlinux.org' >/dev/null 2>&1
		fi
	fi
}

net_connect() {
	if [[ $NONET ]] || chk_connect; then
		return 0
	elif hash nmtui >/dev/null 2>&1; then
		tput civis
		if [[ $TERM == 'linux' ]]; then
			printf "%b" "\e]P1191919" "\e]P4191919" # fix up the nasty default colours of nmtui
			nmtui-connect
			termcol # restore defaults
		else
			nmtui-connect
		fi
	elif hash iwctl >/dev/null 2>&1; then
		echo "To list available commands for iwd use the command: help"
		echo "For more info see: https://wiki.archlinux.org/title/Iwd#Usage"
		tput civis
		iwctl
	else
		return 1
	fi
	chk_connect
}

is_bg_install() {
	[[ $BG_PID ]] || return 0
	msg "Install Running" "\nA background install process is currently running.\n" 2
	return 1
}

system_devices() {
	IGNORE_DEV="$(lsblk -lno NAME,MOUNTPOINT | awk '/\/run\/archiso\/bootmnt/ {sub(/[1-9]/, ""); print $1}')"
	DEVS="$(lsblk -lno TYPE,PATH,SIZE,MODEL | awk '/disk/ && !'"/${IGNORE_DEV:-NONEXX}/"' {print $2, $3 "__" $4}')"
	DEV_COUNT=$(wc -l <<<"$DEVS")

	if [[ -z $DEVS ]]; then
		msg "Device Error" "\nNo available devices...\n\nExiting..\n" 2
		die 1
	fi
}

system_identify() {
	if [[ $VIRT != 'none' ]]; then
		UCODE=''
	elif grep -q 'AuthenticAMD' /proc/cpuinfo; then
		UCODE="amd-ucode"
	elif grep -q 'GenuineIntel' /proc/cpuinfo; then
		UCODE="intel-ucode"
	fi

	modprobe -q efivarfs >/dev/null 2>&1

	if [[ -d /sys/firmware/efi/efivars ]]; then
		SYS="UEFI"
		grep -q /sys/firmware/efi/efivars /proc/mounts || mount -t efivarfs efivarfs /sys/firmware/efi/efivars
	else
		SYS="BIOS"
	fi

	if hash nmtui >/dev/null 2>&1 && [[ $(systemctl is-active NetworkManager.service) == "active" ]]; then
		NET_TYPE=networkmanager
	else
		NET_TYPE=iwd
	fi
}

###############################################################################
# entry point

termcol
dialog_cfg

MISSING=""
for i in dialog find parted curl arch-chroot; do
	hash $i >/dev/null 2>&1 || MISSING+="$i "
done

if [[ $MISSING ]]; then
	printf "The following package(s) need to be installed:\n\n\t%s\n" "$MISSING"
	die 1
elif ((UID != 0)); then
	msg "Not Root" "\nThe installer must be run as root.\n\nExiting..\n" 2
	die 1
elif ! grep -qm 1 ' lm ' /proc/cpuinfo; then
	msg "Not x86_64" "\nThe installer only supports x86_64 architectures.\n\nExiting..\n" 2
	die 1
fi

trap 'printf "\n^C\n" && die 1' INT

while getopts ":hcnr:fDtb:m:d:" OPT; do
	case "$OPT" in
	D) debug ;;
	h) usage "${0##*/}" ;;
	n) NOMOUNT=true ;;
	m) MNT="$OPTARG" ;;
	d) DIST="$OPTARG" ;;
	c) NONET=true ;;
	f) NOFONT=true ;;
	t) TEARFREE=true ;;
	r)
		if [[ ! -b $OPTARG ]]; then
			msg "Invalid Root" "\nThe installer expects a full path to a block device for root, e.g. /dev/sda2.\n\nExiting..\n" 2
			die 1
		fi
		ROOT="$OPTARG"
		;;
	b)
		if [[ ! -b $OPTARG ]]; then
			msg "Invalid Boot" "\nThe installer expects a full path to a block device for boot, e.g. /dev/sda1.\n\nExiting..\n" 2
			die 1
		fi
		BOOT="$OPTARG"
		;;
	\?)
		echo "invalid option: $OPTARG"
		die 2
		;;
	esac
done

if [[ ! -d $MNT ]]; then
	msg "Invalid Mountpoint" "\nThe installer expects an existing directory for mounting.\n\nExiting..\n" 2
	die 2
elif [[ -z $DIST ]]; then
	msg "Invalid Distribution" "\nThe distribution name cannot be empty.\n\nExiting..\n" 2
	die 2
fi

system_identify
system_devices

if [[ $NOMOUNT ]]; then
	if [[ -z $ROOT || ($SYS == 'UEFI' && -z $BOOT) ]]; then
		msg "Invalid Partitions" "$_errpart" 0
		die 2
	fi
	if [[ $BOOT ]]; then
		part_bootdev
		[[ $BOOT != "$ROOT" ]] && SEP_BOOT=true
	fi
fi

if [[ -z $NOFONT ]]; then
	if [[ $TERM == 'linux' ]]; then
		if [[ -f /tmp/font ]]; then
			FONT="$(</tmp/font)"
			: "${FONT=ter-i16n}" # if FONT is empty we reset the default 16
			setfont "$FONT"
		else
			fontsize=16
			while [[ $TERM == 'linux' && ! -f /tmp/font ]]; do
				dlg fontsize menu "Font Size" "\nSelect a font size from the list below.\n\ndefault: 16" \
					12 "setfont ter-i12n" 14 "setfont ter-i14n" 16 "setfont ter-i16n" 18 "setfont ter-i18n" \
					20 "setfont ter-i20n" 22 "setfont ter-i22n" 24 "setfont ter-i24n" 28 "setfont ter-i28n" \
					32 "setfont ter-i32n" || break

				FONT="ter-i${fontsize}n"
				setfont "$FONT"
				yesno "Font Size" "\nKeep the currently set font size?\n" && echo "ter-i${fontsize}n" >/tmp/font
			done
		fi
	fi
fi

if [[ ! -f /tmp/weld ]]; then
	msg "Welcome" "\nThis script will help you get $DIST installed and setup on your system.\n\nIf you are unsure about an option, the default or most common option\nwill be described, if it is not the first selected entry will be the default.\n\n\nMenu Navigation:\n\n - Select items with the arrow keys or the highlighted key.\n - Repeatedly pressing the highlighted key for an option will cycle through options beginning with that key.\n - Use [Space] to toggle check boxes and [Enter] to accept selection.\n - Use [Escape] or select the cancel/exit button to exit a menu or dialog.\n - Switch between fields using [Tab] or the arrow keys.\n - Use [Page Up] and [Page Down] to jump whole pages.\n"
	touch /tmp/weld
fi

if ! select_keymap; then
	clear
	die 0
elif ! net_connect; then
	msg "Not Connected" "\nThis installer requires an active internet connection.\n\nExiting..\n" 2
	die 1
fi

mirrorpid=''

if [[ ! -f /tmp/new ]]; then
	msg "Update" "\nChecking for installer updates.\n" 0
	(reflector --list-countries 2>/dev/null | sed '1,2d' | awk 'NF{NF--}; {print}' >/tmp/mcountry) &
	echo $! >/tmp/mirrorpid

elif [[ -f /tmp/mirrorpid ]]; then
	mirrorpid=$(</tmp/mirrorpid)
	rm /tmp/mirrorpid
fi

# warn before starting the background process
if [[ $NOMOUNT ]]; then
	wrn="\nA background install process will begin early when using -n flag\n\nSome files may be overwritten during the process\n"
	yesno "Data Warning" "$wrn\nProceed?\n" || die 0
	install_background
fi

while :; do
	main
done

touch "$FLAG_FILE"

# vim:fdm=marker:fmr={,}
