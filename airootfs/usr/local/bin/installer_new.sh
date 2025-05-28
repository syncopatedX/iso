#!/bin/bash

# installer_new.sh - Refactored Arch Linux Installer
# This script handles user interaction, disk setup, base installation,
# and then hands off to Ansible for system configuration.

set -eo pipefail # Exit on error, treat unset variables as an error, and propagate pipeline errors

# --- Configuration ---
DIST_NAME="Syncopated"
INSTALL_LOG="/tmp/installer_new.log"
ANS_VARS_FILE="/mnt/etc/ansible/install_vars.yml"
ANS_PLAYBOOK_DIR_HOST="./ansible_setup" # Default, can be overridden
ANS_PLAYBOOK_DIR_TARGET="/mnt/root/ansible_setup"
MAIN_PLAYBOOK="site.yml"
DIALOG_OPTS=(--cr-wrap --backtitle "$DIST_NAME Installer")
CHECKPOINT_FILE="/tmp/installer_checkpoint.txt"
TMP_ANS_FILE="/tmp/dialog_answer.$$"

# --- Script Global Variables ---
FIRMWARE_TYPE=""
TARGET_DISK=""
PARTITION_SCHEME=""
BOOT_PARTITION_DEVICE=""
ROOT_PARTITION_DEVICE=""
SWAP_CHOICE="none"
SWAP_DEVICE_OR_SIZE=""
ROOT_FS_TYPE="ext4"
LUKS_ENABLED="false"
LUKS_PASSWORD=""
LUKS_ROOT_MAPPER_NAME="cryptroot"
LUKS_OPTIONS="" # For advanced LUKS setup
LVM_ENABLED="false"
LVM_PV_DEVICES=()
LVM_VG_NAME="vg0"
LVM_LVS_CONFIG=() # Array of strings like "name:size:fstype:mountpoint"
LVM_LV_ROOT_NAME="lv_root"
LVM_LV_ROOT_SIZE="50%VG" # Default to 50% of Volume Group size
LVM_LV_HOME_ENABLED="false"
LVM_LV_HOME_NAME="lv_home"
LVM_LV_HOME_SIZE="100%FREE" # Default to remaining space
LVM_LV_HOME_FSTYPE="" # Will default to ROOT_FS_TYPE if enabled
LVM_LV_SWAP_ENABLED="false"
LVM_LV_SWAP_NAME="lv_swap"
LVM_LV_SWAP_SIZE="4G" # Default swap size
HOSTNAME="archlinux"
USERNAME="archuser"
USER_PASSWORD=""
ROOT_PASSWORD=""
TIMEZONE="UTC"
LOCALE="en_US.UTF-8"
KEYMAP="us"
CONSOLE_KEYMAP="us"
KERNEL_CHOICE="linux"
BOOTLOADER_CHOICE="grub"
WM_DE_CHOICE="none"
ADDITIONAL_PACKAGES_STRING="" # Space separated
BTRFS_SUBVOLUMES_ENABLED="false"
BTRFS_DEFAULT_SUBVOLUMES=("@:/snapshots" "@/home:/home/snapshots") # Example, if creating them
MIRROR_COUNTRY="US" # Default mirror country

# --- Logging ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] - $1" | tee -a "$INSTALL_LOG"
}

log_cmd() {
    local cmd_string="$*"
    log "Executing: $cmd_string"
    # Using subshell for eval to avoid variable scope issues with its output redirection
    if (eval "$cmd_string") >> "$INSTALL_LOG" 2>&1; then
        log "SUCCESS: $cmd_string"
        return 0
    else
        local exit_code=$?
        log "ERROR: Command failed with exit code $exit_code: $cmd_string"
        return "$exit_code"
    fi
}

# --- Error Handling ---
handle_error() {
    local error_message="$1"
    local exit_code="${2:-1}"
    log "FATAL ERROR: $error_message"
    dialog "${DIALOG_OPTS[@]}" --title "Fatal Error" --msgbox "An unrecoverable error occurred:\n\n$error_message\n\nCheck $INSTALL_LOG for details." 10 70
    cleanup
    exit "$exit_code"
}

trap 'handle_error "An unexpected error occurred at line $LINENO ($BASH_COMMAND)." $?' ERR

# --- Dialog Helper ---
run_dialog() {
    local __result_var="$1"
    local __dialog_type="$2"
    local __title="$3"
    local __text="$4"
    shift 4
    local __ret_code=0
    >"$TMP_ANS_FILE"
    case "$__dialog_type" in
        input) dialog "${DIALOG_OPTS[@]}" --title "$__title" --inputbox "$__text" 10 70 "$@" 2> "$TMP_ANS_FILE"; __ret_code=$? ;;
        password) dialog "${DIALOG_OPTS[@]}" --title "$__title" --passwordbox "$__text" 10 70 "$@" 2> "$TMP_ANS_FILE"; __ret_code=$? ;;
        yesno)
            dialog "${DIALOG_OPTS[@]}" --title "$__title" --yesno "$__text" 10 70 "$@"
            __ret_code=$?
            if [[ $__ret_code -eq 0 ]]; then eval "$__result_var='yes'"; else eval "$__result_var='no'"; fi
            return $__ret_code ;;
        menu) dialog "${DIALOG_OPTS[@]}" --title "$__title" --menu "$__text" 0 0 0 "$@" 2> "$TMP_ANS_FILE"; __ret_code=$? ;;
        checklist) dialog "${DIALOG_OPTS[@]}" --title "$__title" --checklist "$__text" 0 0 0 "$@" 2> "$TMP_ANS_FILE"; __ret_code=$? ;;
        radiolist) dialog "${DIALOG_OPTS[@]}" --title "$__title" --radiolist "$__text" 0 0 0 "$@" 2> "$TMP_ANS_FILE"; __ret_code=$? ;;
        msgbox) dialog "${DIALOG_OPTS[@]}" --title "$__title" --msgbox "$__text" 10 70 "$@"; __ret_code=$? ;;
        infobox) dialog "${DIALOG_OPTS[@]}" --title "$__title" --infobox "$__text" 5 70 "$@"; sleep 2; __ret_code=0 ;;
        *) log "ERROR: Unknown dialog type '$__dialog_type'"; return 1 ;;
    esac
    if [[ $__ret_code -eq 0 && -f "$TMP_ANS_FILE" ]]; then
        # Only attempt to assign to __result_var if it's not empty.
        # This prevents errors for dialog types like infobox that don't set a variable.
        if [[ -n "$__result_var" ]]; then
            eval "$__result_var=\"\$(<'$TMP_ANS_FILE')\""
        fi
        rm -f "$TMP_ANS_FILE" # Clean up the temp file
    elif [[ $__ret_code -ne 0 ]]; then
        log "Dialog '$__title' cancelled or failed (code $__ret_code)."
        rm -f "$TMP_ANS_FILE" # Also remove if dialog failed and file might exist
        return 1
    else
        # If __ret_code was 0, but $TMP_ANS_FILE didn't exist (e.g. msgbox, infobox don't create it)
        # or if __result_var was empty (infobox case) and eval was skipped.
        # Ensure $TMP_ANS_FILE (if it somehow exists for non-output dialogs) is removed.
        rm -f "$TMP_ANS_FILE"
    fi
    return 0
}

# --- Checkpointing ---
save_checkpoint() {
    local step_name="$1"
    log "Saving checkpoint: $step_name"
    echo "$step_name" > "$CHECKPOINT_FILE"
    declare -p FIRMWARE_TYPE TARGET_DISK PARTITION_SCHEME BOOT_PARTITION_DEVICE ROOT_PARTITION_DEVICE SWAP_CHOICE SWAP_DEVICE_OR_SIZE ROOT_FS_TYPE LUKS_ENABLED LUKS_PASSWORD LUKS_ROOT_MAPPER_NAME LUKS_OPTIONS LVM_ENABLED LVM_PV_DEVICES LVM_VG_NAME LVM_LVS_CONFIG LVM_LV_ROOT_NAME LVM_LV_ROOT_SIZE LVM_LV_HOME_ENABLED LVM_LV_HOME_NAME LVM_LV_HOME_SIZE LVM_LV_HOME_FSTYPE LVM_LV_SWAP_ENABLED LVM_LV_SWAP_NAME LVM_LV_SWAP_SIZE HOSTNAME USERNAME USER_PASSWORD ROOT_PASSWORD TIMEZONE LOCALE KEYMAP CONSOLE_KEYMAP KERNEL_CHOICE BOOTLOADER_CHOICE WM_DE_CHOICE ADDITIONAL_PACKAGES_STRING BTRFS_SUBVOLUMES_ENABLED MIRROR_COUNTRY > "${CHECKPOINT_FILE}.vars" 2>/dev/null || true
}

load_checkpoint() {
    if [[ -f "$CHECKPOINT_FILE" && -f "${CHECKPOINT_FILE}.vars" ]]; then
        current_step=$(cat "$CHECKPOINT_FILE")
        log "Loaded checkpoint: $current_step"
        # shellcheck source=/dev/null
        source "${CHECKPOINT_FILE}.vars" 2>/dev/null || log "Warning: Could not source checkpoint variables."
        return 0
    fi
    log "No checkpoint file found."
    current_step=""
    return 0
}

# --- Utility Functions ---
detect_firmware_type() {
    if [ -d /sys/firmware/efi/efivars ]; then FIRMWARE_TYPE="UEFI"; else FIRMWARE_TYPE="BIOS"; fi
    log "Detected firmware type: $FIRMWARE_TYPE"
}
get_available_disks() { lsblk -dno NAME,SIZE,MODEL | awk '{model=$3; for(i=4; i<=NF; i++) model=model" "$i; gsub(/^ *| *$/, "", model); if (model == "") model="N/A"; printf "%s \"%s - %s\" off\n", "/dev/"$1, $2, model}'; }
get_locales() { awk '/UTF-8/ && !/^#/ {gsub(/\.UTF-8.*/, ".UTF-8"); print $1 " \"\" off"}' /etc/locale.gen | sort -u; }
get_timezones() { find /usr/share/zoneinfo -type f -printf "%P\n" | sort | awk '{print $1 " \"\" off"}'; }
get_keymaps() { localectl list-x11-keymap-layouts | awk '{print $1 " \"\" off"}'; }
get_console_keymaps() { find /usr/share/kbd/keymaps -type f -name '*.map.gz' -printf "%f\n" | sed 's/\.map\.gz$//' | sort -u | awk '{print $1 " \"\" off"}'; }
get_partition_path() {
    local disk="$1"; local number="$2"
    if [[ "$disk" == /dev/nvme* ]]; then echo "${disk}p${number}"; else echo "${disk}${number}"; fi
}

cleanup() {
    log "Performing cleanup..."
    # Unmount in reverse order of typical mounting
    mount | grep '^/dev/' | awk '{print $3}' | sort -r | while read -r mp; do
        if [[ "$mp" == /mnt* ]]; then
            umount "$mp" 2>/dev/null && log "Unmounted $mp" || log "Warning: Failed to unmount $mp"
        fi
    done
    if mountpoint -q /mnt; then umount /mnt 2>/dev/null || log "Warning: Failed to unmount /mnt finally"; fi

    if [[ "$LUKS_ENABLED" == "true" && -b "/dev/mapper/$LUKS_ROOT_MAPPER_NAME" ]]; then
        cryptsetup close "$LUKS_ROOT_MAPPER_NAME" 2>/dev/null && log "Closed LUKS device $LUKS_ROOT_MAPPER_NAME" || log "Warning: Failed to close LUKS $LUKS_ROOT_MAPPER_NAME"
    fi

    if [[ "$LVM_ENABLED" == "true" && -n "$LVM_VG_NAME" ]]; then
        if vgdisplay "$LVM_VG_NAME" &>/dev/null; then
             vgchange -an "$LVM_VG_NAME" 2>/dev/null && log "Deactivated LVM VG $LVM_VG_NAME" || log "Warning: Failed to deactivate LVM VG $LVM_VG_NAME"
        fi
    fi
    rm -f "$TMP_ANS_FILE"
    log "Cleanup attempt finished."
}

# --- Core Functions ---
gather_install_parameters() {
    log "Gathering installation parameters..."
    detect_firmware_type

    # Pre-requisites
    run_dialog CONSOLE_KEYMAP_CHOICE radiolist "Console Keymap" "Select console keymap:" $(get_console_keymaps) || handle_error "Console keymap selection cancelled."
    CONSOLE_KEYMAP="${CONSOLE_KEYMAP_CHOICE:-us}"; log_cmd "loadkeys $CONSOLE_KEYMAP" || log "Warn: Failed to set console keymap $CONSOLE_KEYMAP"

    run_dialog KEYMAP_CHOICE radiolist "X11 Keyboard Layout" "Select X11 keyboard layout:" $(get_keymaps) || handle_error "X11 keymap selection cancelled."
    KEYMAP="${KEYMAP_CHOICE:-us}"

    # Mirror selection (simple version)
    run_dialog MIRROR_COUNTRY_TEMP input "Mirror Country" "Enter comma-separated country codes for mirrors (e.g., US,DE):" "$MIRROR_COUNTRY" || handle_error "Mirror country selection cancelled."
    MIRROR_COUNTRY="$MIRROR_COUNTRY_TEMP"
    log "Mirror countries: $MIRROR_COUNTRY"
    if [[ -n "$MIRROR_COUNTRY" && "$MIRROR_COUNTRY" != "skip" ]]; then
        log "Updating mirrorlist for countries: $MIRROR_COUNTRY..."
        run_dialog "" infobox "Updating Mirrors" "Fetching fastest mirrors for $MIRROR_COUNTRY..." 5 70
        log_cmd "reflector --country \"$MIRROR_COUNTRY\" --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist" || log "Warning: reflector failed. Using existing mirrorlist."
    else
        log "Skipping reflector mirror update."
    fi

    # Disk and Partitioning
    run_dialog TARGET_DISK_CHOICE radiolist "Target Disk" "Select target disk for installation:" $(get_available_disks) || handle_error "Target disk selection cancelled."
    TARGET_DISK="${TARGET_DISK_CHOICE}"; [[ -z "$TARGET_DISK" ]] && handle_error "No target disk selected."
    log "Target disk: $TARGET_DISK"

    local part_options_uefi=("auto_gpt" "Automatic GPT partitioning (UEFI Recommended)" "on" \
                             "manual_gpt" "Manual partitioning with cgdisk (GPT)" "off")
    local part_options_bios=("auto_mbr" "Automatic MBR partitioning (BIOS Recommended)" "on" \
                             "manual_mbr" "Manual partitioning with cfdisk (MBR)" "off")
    if [[ "$FIRMWARE_TYPE" == "UEFI" ]]; then
        run_dialog PARTITION_SCHEME radiolist "Partitioning Scheme (UEFI)" "Select partitioning scheme:" "${part_options_uefi[@]}" || handle_error "Partitioning scheme selection cancelled."
    else
        run_dialog PARTITION_SCHEME radiolist "Partitioning Scheme (BIOS)" "Select partitioning scheme:" "${part_options_bios[@]}" || handle_error "Partitioning scheme selection cancelled."
    fi
    log "Partition scheme: $PARTITION_SCHEME"

    local fs_options=("ext4" "ext4 filesystem" "on" \
                      "btrfs" "BTRFS filesystem" "off" \
                      "xfs" "XFS filesystem" "off" \
                      "f2fs" "F2FS (Flash-Friendly File System)" "off")
    run_dialog ROOT_FS_TYPE radiolist "Root Filesystem Type" "Select filesystem for root partition:" "${fs_options[@]}" || handle_error "Root FS type selection cancelled."
    log "Root filesystem type: $ROOT_FS_TYPE"

    if [[ "$ROOT_FS_TYPE" == "btrfs" ]]; then
        run_dialog BTRFS_SUBVOL_CHOICE yesno "BTRFS Subvolumes" "Create default BTRFS subvolumes (@ for /, @home for /home)?" || handle_error "BTRFS subvolume choice cancelled."
        [[ "$BTRFS_SUBVOL_CHOICE" == "yes" ]] && BTRFS_SUBVOLUMES_ENABLED="true"
    fi

    run_dialog LUKS_CHOICE yesno "Disk Encryption (LUKS)" "Enable LUKS encryption for the root/LVM volume?" || handle_error "LUKS choice cancelled."
    if [[ "$LUKS_CHOICE" == "yes" ]]; then
        LUKS_ENABLED="true"
        run_dialog LUKS_PASSWORD_TEMP password "LUKS Password" "Enter LUKS encryption password:" || handle_error "LUKS password entry cancelled."
        local luks_confirm; run_dialog luks_confirm password "LUKS Password (Confirm)" "Confirm LUKS password:" || handle_error "LUKS password confirm cancelled."
        [[ "$LUKS_PASSWORD_TEMP" != "$luks_confirm" ]] && handle_error "LUKS passwords do not match."; [[ -z "$LUKS_PASSWORD_TEMP" ]] && handle_error "LUKS password cannot be empty."
        LUKS_PASSWORD="$LUKS_PASSWORD_TEMP"
        run_dialog LUKS_OPTIONS input "Advanced LUKS Options" "Enter advanced LUKS options (e.g., --cipher aes-xts-plain64 --key-size 512).\nLeave blank for defaults." "" || handle_error "Advanced LUKS options entry cancelled."
        if [[ -n "$LUKS_OPTIONS" ]]; then
            log "Advanced LUKS options set: $LUKS_OPTIONS"
        fi
        log "LUKS encryption enabled."
    fi

    run_dialog LVM_CHOICE yesno "Logical Volume Management (LVM)" "Use LVM (e.g., for root/home on LUKS, or flexible partitioning)?" || handle_error "LVM choice cancelled."
    if [[ "$LVM_CHOICE" == "yes" ]]; then
        LVM_ENABLED="true"; log "LVM enabled."
        run_dialog LVM_VG_NAME_TEMP input "LVM Volume Group Name" "Enter LVM Volume Group name (e.g., vg0):" "$LVM_VG_NAME" || handle_error "LVM VG name cancelled."
        LVM_VG_NAME="${LVM_VG_NAME_TEMP:-vg0}"

        run_dialog LVM_LV_ROOT_NAME_TEMP input "LVM Root LV Name" "Enter Root Logical Volume name (e.g., lv_root):" "$LVM_LV_ROOT_NAME" || handle_error "LVM Root LV name cancelled."
        LVM_LV_ROOT_NAME="${LVM_LV_ROOT_NAME_TEMP:-lv_root}"
        run_dialog LVM_LV_ROOT_SIZE_TEMP input "LVM Root LV Size" "Enter Root LV size (e.g., 20G, 50%VG):" "$LVM_LV_ROOT_SIZE" || handle_error "LVM Root LV size cancelled."
        LVM_LV_ROOT_SIZE="${LVM_LV_ROOT_SIZE_TEMP:-50%VG}"

        run_dialog LVM_LV_HOME_CHOICE yesno "Separate Home LV" "Create a separate Logical Volume for /home?" || handle_error "Home LV choice cancelled."
        if [[ "$LVM_LV_HOME_CHOICE" == "yes" ]]; then
            LVM_LV_HOME_ENABLED="true"
            run_dialog LVM_LV_HOME_NAME_TEMP input "LVM Home LV Name" "Enter Home Logical Volume name (e.g., lv_home):" "$LVM_LV_HOME_NAME" || handle_error "LVM Home LV name cancelled."
            LVM_LV_HOME_NAME="${LVM_LV_HOME_NAME_TEMP:-lv_home}"
            run_dialog LVM_LV_HOME_SIZE_TEMP input "LVM Home LV Size" "Enter Home LV size (e.g., 100G, 100%FREE):" "$LVM_LV_HOME_SIZE" || handle_error "LVM Home LV size cancelled."
            LVM_LV_HOME_SIZE="${LVM_LV_HOME_SIZE_TEMP:-100%FREE}"
            # Default Home LV fstype to ROOT_FS_TYPE, can be overridden later if complex LVM setup is added
            LVM_LV_HOME_FSTYPE="$ROOT_FS_TYPE"
        else
            LVM_LV_HOME_ENABLED="false"
        fi

        # Offer Swap LV only if swap choice is 'partition' and LVM is enabled
        if [[ "$SWAP_CHOICE" == "partition" ]]; then # SWAP_CHOICE is determined earlier in manual_partition_flow or defaulted
             run_dialog LVM_LV_SWAP_CHOICE yesno "LVM Swap LV" "Create a Logical Volume for swap?" || handle_error "Swap LV choice cancelled."
             if [[ "$LVM_LV_SWAP_CHOICE" == "yes" ]]; then
                LVM_LV_SWAP_ENABLED="true"
                run_dialog LVM_LV_SWAP_NAME_TEMP input "LVM Swap LV Name" "Enter Swap Logical Volume name (e.g., lv_swap):" "$LVM_LV_SWAP_NAME" || handle_error "LVM Swap LV name cancelled."
                LVM_LV_SWAP_NAME="${LVM_LV_SWAP_NAME_TEMP:-lv_swap}"
                run_dialog LVM_LV_SWAP_SIZE_TEMP input "LVM Swap LV Size" "Enter Swap LV size (e.g., 4G, 8192M):" "$LVM_LV_SWAP_SIZE" || handle_error "LVM Swap LV size cancelled."
                LVM_LV_SWAP_SIZE="${LVM_LV_SWAP_SIZE_TEMP:-4G}"
             else
                LVM_LV_SWAP_ENABLED="false"
             fi
        else
            # If swap choice is not 'partition', or LVM is not enabled, then LVM_LV_SWAP_ENABLED remains false.
            # If SWAP_CHOICE is 'file', it will be handled by Ansible. If 'none', no swap.
            LVM_LV_SWAP_ENABLED="false"
        fi
        log "LVM Configuration: VG=$LVM_VG_NAME, RootLV=${LVM_LV_ROOT_NAME}(${LVM_LV_ROOT_SIZE}), HomeLV_Enabled=$LVM_LV_HOME_ENABLED, SwapLV_Enabled=$LVM_LV_SWAP_ENABLED"
    fi

    # System Configuration
    run_dialog HOSTNAME input "Hostname" "Enter system hostname:" "$HOSTNAME" || handle_error "Hostname entry cancelled."
    [[ -z "$HOSTNAME" ]] && HOSTNAME="archlinux"

    run_dialog USERNAME input "Username" "Enter username for the new user:" "$USERNAME" || handle_error "Username entry cancelled."
    [[ -z "$USERNAME" ]] && USERNAME="archuser"

    run_dialog USER_PASSWORD_TEMP password "User Password" "Enter password for $USERNAME:" || handle_error "User password entry cancelled."
    local user_pass_confirm; run_dialog user_pass_confirm password "User Password (Confirm)" "Confirm for $USERNAME:" || handle_error "User password confirm cancelled."
    [[ "$USER_PASSWORD_TEMP" != "$user_pass_confirm" ]] && handle_error "User passwords do not match."; [[ -z "$USER_PASSWORD_TEMP" ]] && handle_error "User password empty."
    USER_PASSWORD="$USER_PASSWORD_TEMP"

    run_dialog ROOT_PASSWORD_TEMP password "Root Password" "Enter root password:" || handle_error "Root password entry cancelled."
    local root_pass_confirm; run_dialog root_pass_confirm password "Root Password (Confirm)" "Confirm root password:" || handle_error "Root password confirm cancelled."
    [[ "$ROOT_PASSWORD_TEMP" != "$root_pass_confirm" ]] && handle_error "Root passwords do not match."; [[ -z "$ROOT_PASSWORD_TEMP" ]] && handle_error "Root password empty."
    ROOT_PASSWORD="$ROOT_PASSWORD_TEMP"

    run_dialog TIMEZONE_CHOICE radiolist "Timezone" "Select timezone:" $(get_timezones) || handle_error "Timezone selection cancelled."
    TIMEZONE="${TIMEZONE_CHOICE:-UTC}"

    run_dialog LOCALE_CHOICE radiolist "System Locale" "Select system locale:" $(get_locales) || handle_error "Locale selection cancelled."
    LOCALE="${LOCALE_CHOICE:-en_US.UTF-8}"

    # Software Selection
    local kernel_options=("linux" "Standard Linux kernel" "on" "linux-lts" "Long Term Support" "off" "linux-zen" "Zen kernel" "off")
    run_dialog KERNEL_CHOICE radiolist "Kernel" "Select kernel:" "${kernel_options[@]}" || handle_error "Kernel selection cancelled."

    local bootloader_opts_uefi=("grub" "GRUB (UEFI)" "on" "systemd-boot" "systemd-boot" "off")
    local bootloader_opts_bios=("grub" "GRUB (BIOS)" "on")
    if [[ "$FIRMWARE_TYPE" == "UEFI" ]]; then
        run_dialog BOOTLOADER_CHOICE radiolist "Bootloader (UEFI)" "Select bootloader:" "${bootloader_opts_uefi[@]}" || handle_error "Bootloader selection cancelled."
    else
        run_dialog BOOTLOADER_CHOICE radiolist "Bootloader (BIOS)" "Select bootloader:" "${bootloader_opts_bios[@]}" || handle_error "Bootloader selection cancelled."
    fi

    local wm_options=("none" "None (console only)" "on" \
                      "i3" "i3 Window Manager" "off" \
                      "gnome" "GNOME Desktop" "off" \
                      "plasma" "KDE Plasma Desktop" "off" \
                      "xfce4" "XFCE4 Desktop" "off")
    run_dialog WM_DE_CHOICE radiolist "Desktop/WM" "Select Desktop Environment or Window Manager:" "${wm_options[@]}" || handle_error "Desktop/WM selection cancelled."

    run_dialog ADDITIONAL_PACKAGES_STRING input "Additional Packages" "Enter space-separated list of additional packages to install (e.g., firefox gimp):" "vim git networkmanager" || handle_error "Additional packages entry cancelled."

    save_checkpoint "parameters_gathered"
}

# --- Disk Setup Functions ---
auto_partition_gpt_uefi() {
    log "Automatic GPT partitioning on $TARGET_DISK for UEFI with $ROOT_FS_TYPE..."
    log_cmd "sgdisk --zap-all $TARGET_DISK" || handle_error "Failed to zap $TARGET_DISK."
    log_cmd "parted -s $TARGET_DISK mklabel gpt" || handle_error "Failed to create GPT label."

    # ESP
    log_cmd "parted -s $TARGET_DISK mkpart ESP fat32 1MiB 513MiB" || handle_error "Failed to create ESP."
    log_cmd "parted -s $TARGET_DISK set 1 esp on" || handle_error "Failed to set ESP flag."
    BOOT_PARTITION_DEVICE=$(get_partition_path "$TARGET_DISK" 1)
    log_cmd "mkfs.fat -F32 $BOOT_PARTITION_DEVICE" || handle_error "Failed to format ESP $BOOT_PARTITION_DEVICE."

    # Root partition (rest of the disk for simplicity, swap can be a file later)
    local root_part_num=2
    ROOT_PARTITION_DEVICE=$(get_partition_path "$TARGET_DISK" $root_part_num)
    log_cmd "parted -s $TARGET_DISK mkpart primary $ROOT_FS_TYPE 513MiB 100%" || handle_error "Failed to create root partition."

    local device_for_lvm_or_fs="$ROOT_PARTITION_DEVICE" # Start with the raw partition as the candidate

    if [[ "$LUKS_ENABLED" == "true" ]]; then
        log "Setting up LUKS on $ROOT_PARTITION_DEVICE (which is currently $device_for_lvm_or_fs)..."
        echo -n "$LUKS_PASSWORD" | cryptsetup luksFormat --type luks2 "$ROOT_PARTITION_DEVICE" -d - $LUKS_OPTIONS || handle_error "LUKS format failed on $ROOT_PARTITION_DEVICE."
        echo -n "$LUKS_PASSWORD" | cryptsetup open "$ROOT_PARTITION_DEVICE" "$LUKS_ROOT_MAPPER_NAME" -d - || handle_error "LUKS open failed for $ROOT_PARTITION_DEVICE."
        device_for_lvm_or_fs="/dev/mapper/$LUKS_ROOT_MAPPER_NAME" # Update to LUKS device
        log "LUKS setup complete. Device for LVM or Filesystem is now $device_for_lvm_or_fs"
    fi

    if [[ "$LVM_ENABLED" == "true" ]]; then
        log "LVM is enabled. Setting up LVM on $device_for_lvm_or_fs..."
        _setup_lvm_on_device "$device_for_lvm_or_fs"
        # _setup_lvm_on_device updates global ROOT_PARTITION_DEVICE to the LVM LV path for root.
        # It also handles formatting/mounting Home LV and creating/activating Swap LV if configured.
        log "LVM setup complete. Global ROOT_PARTITION_DEVICE is now $ROOT_PARTITION_DEVICE"
    else
        # If LVM is not enabled, the ROOT_PARTITION_DEVICE for formatting is whatever device_for_lvm_or_fs ended up as
        # (either the raw partition or the LUKS mapped device).
        ROOT_PARTITION_DEVICE="$device_for_lvm_or_fs"
        log "LVM not enabled. ROOT_PARTITION_DEVICE for formatting is $ROOT_PARTITION_DEVICE"
    fi

    # Format and mount the final root device.
    # Note: If LVM is used and a separate Home LV was created, _setup_lvm_on_device has already formatted and mounted it.
    # format_and_mount_root needs to be aware of this if creating BTRFS @home subvolume.
    # For now, we assume format_and_mount_root will correctly handle the ROOT_PARTITION_DEVICE.
    # Any LVM Home LV is independently mounted by _setup_lvm_on_device.
    format_and_mount_root "$ROOT_PARTITION_DEVICE"

    log_cmd "mkdir -p /mnt/boot" || handle_error "Failed to create /mnt/boot."
    log_cmd "mount $BOOT_PARTITION_DEVICE /mnt/boot" || handle_error "Failed to mount ESP $BOOT_PARTITION_DEVICE to /mnt/boot."

    # Swap (file based, handled by Ansible)
    SWAP_CHOICE="file" # Default to swap file for auto modes
    SWAP_DEVICE_OR_SIZE="2G" # Default size, Ansible can adjust
}

auto_partition_mbr_bios() {
    log "Automatic MBR partitioning on $TARGET_DISK for BIOS with $ROOT_FS_TYPE..."
    log_cmd "sgdisk --zap-all $TARGET_DISK" || handle_error "Failed to zap $TARGET_DISK." # sgdisk can zap MBR too
    log_cmd "parted -s $TARGET_DISK mklabel msdos" || handle_error "Failed to create MBR label."

    # Root partition (using most of the disk)
    # A small /boot is not strictly necessary for BIOS unless complex LUKS/LVM without GRUB support.
    # For simplicity, one root partition. GRUB can handle LUKS on BIOS if /boot is inside.
    ROOT_PARTITION_DEVICE=$(get_partition_path "$TARGET_DISK" 1)
    log_cmd "parted -s $TARGET_DISK mkpart primary $ROOT_FS_TYPE 1MiB 100%" || handle_error "Failed to create root partition."
    log_cmd "parted -s $TARGET_DISK set 1 boot on" || handle_error "Failed to set boot flag on $ROOT_PARTITION_DEVICE."


    local device_for_lvm_or_fs="$ROOT_PARTITION_DEVICE" # Start with the raw partition

    if [[ "$LUKS_ENABLED" == "true" ]]; then
        log "Setting up LUKS on $ROOT_PARTITION_DEVICE (which is currently $device_for_lvm_or_fs)..."
        echo -n "$LUKS_PASSWORD" | cryptsetup luksFormat --type luks2 "$ROOT_PARTITION_DEVICE" -d - $LUKS_OPTIONS || handle_error "LUKS format failed on $ROOT_PARTITION_DEVICE."
        echo -n "$LUKS_PASSWORD" | cryptsetup open "$ROOT_PARTITION_DEVICE" "$LUKS_ROOT_MAPPER_NAME" -d - || handle_error "LUKS open failed for $ROOT_PARTITION_DEVICE."
        device_for_lvm_or_fs="/dev/mapper/$LUKS_ROOT_MAPPER_NAME" # Update to LUKS device
        log "LUKS setup complete. Device for LVM or Filesystem is now $device_for_lvm_or_fs"
    fi

    if [[ "$LVM_ENABLED" == "true" ]]; then
        log "LVM is enabled. Setting up LVM on $device_for_lvm_or_fs..."
        _setup_lvm_on_device "$device_for_lvm_or_fs"
        # _setup_lvm_on_device updates global ROOT_PARTITION_DEVICE to the LVM LV path for root.
        # It also handles formatting/mounting Home LV and creating/activating Swap LV if configured.
        log "LVM setup complete. Global ROOT_PARTITION_DEVICE is now $ROOT_PARTITION_DEVICE"
    else
        # If LVM is not enabled, the ROOT_PARTITION_DEVICE for formatting is whatever device_for_lvm_or_fs ended up as
        # (either the raw partition or the LUKS mapped device).
        ROOT_PARTITION_DEVICE="$device_for_lvm_or_fs"
        log "LVM not enabled. ROOT_PARTITION_DEVICE for formatting is $ROOT_PARTITION_DEVICE"
    fi

    # Format and mount the final root device.
    format_and_mount_root "$ROOT_PARTITION_DEVICE"
    # Swap (file based, handled by Ansible)
    SWAP_CHOICE="file"
    SWAP_DEVICE_OR_SIZE="2G"
}

format_and_mount_root() {
    local device_to_format="$1"
    log "Formatting $device_to_format as $ROOT_FS_TYPE..."
    if [[ "$ROOT_FS_TYPE" == "btrfs" ]]; then
        log_cmd "mkfs.btrfs -f $device_to_format" || handle_error "mkfs.btrfs failed on $device_to_format."
        log_cmd "mount -o compress=zstd $device_to_format /mnt" || handle_error "Failed to mount BTRFS root $device_to_format."
        if [[ "$BTRFS_SUBVOLUMES_ENABLED" == "true" ]]; then
            log_cmd "btrfs subvolume create /mnt/@" || handle_error "Failed to create @ subvolume."
            log_cmd "btrfs subvolume create /mnt/@home" || handle_error "Failed to create @home subvolume."
            # Potentially snapshots, var, etc.
            log_cmd "btrfs subvolume create /mnt/@snapshots" || true # Optional
            log_cmd "umount /mnt" || handle_error "Failed to unmount BTRFS root for subvolume mounting."
            log_cmd "mount -o subvol=@,compress=zstd $device_to_format /mnt" || handle_error "Failed to mount @ subvolume."
            log_cmd "mkdir -p /mnt/home" || handle_error "Failed to create /mnt/home."
            log_cmd "mount -o subvol=@home,compress=zstd $device_to_format /mnt/home" || handle_error "Failed to mount @home subvolume."
            log_cmd "mkdir -p /mnt/.snapshots" || true
            log_cmd "mount -o subvol=@snapshots,compress=zstd $device_to_format /mnt/.snapshots" || true
        fi
    else # ext4, xfs, f2fs
        log_cmd "mkfs.$ROOT_FS_TYPE -F $device_to_format" || handle_error "mkfs.$ROOT_FS_TYPE failed on $device_to_format."
        log_cmd "mount $device_to_format /mnt" || handle_error "Failed to mount root $device_to_format."
    fi
}


manual_partition_flow() {
    log "Starting manual partitioning flow..."
    run_dialog "" msgbox "Manual Partitioning" "You will be guided to specify partitions for root, boot (if UEFI/separate), and swap (optional).\n\nUse cfdisk (for MBR/BIOS) or cgdisk (for GPT/UEFI) to create partitions first if needed.\nPress OK to open the tool, or Cancel to skip if already partitioned." "cfdisk $TARGET_DISK" "cgdisk $TARGET_DISK"
    local tool_choice
    if [[ "$FIRMWARE_TYPE" == "UEFI" ]]; then
        run_dialog tool_choice yesno "Partitioning Tool" "Open cgdisk for $TARGET_DISK?" "Yes, open cgdisk" "No, already partitioned"
        [[ "$tool_choice" == "yes" ]] && cgdisk "$TARGET_DISK"
    else
        run_dialog tool_choice yesno "Partitioning Tool" "Open cfdisk for $TARGET_DISK?" "Yes, open cfdisk" "No, already partitioned"
        [[ "$tool_choice" == "yes" ]] && cfdisk "$TARGET_DISK"
    fi

    # Get root partition
    local all_parts; all_parts=$(lsblk -lnpo NAME,SIZE "$TARGET_DISK" | awk '{print $1 " ("$2")" " off"}')
    run_dialog ROOT_PART_RAW radiolist "Root Partition" "Select your ROOT partition:" $all_parts || handle_error "Root partition selection cancelled."
    [[ -z "$ROOT_PART_RAW" ]] && handle_error "Root partition not specified."

    # Get boot partition
    if [[ "$FIRMWARE_TYPE" == "UEFI" ]]; then
        run_dialog BOOT_PARTITION_DEVICE radiolist "EFI System Partition (ESP)" "Select your ESP (mounted at /boot or /boot/efi):" $all_parts || handle_error "ESP selection cancelled."
        [[ -z "$BOOT_PARTITION_DEVICE" ]] && handle_error "ESP not specified for UEFI."
    else # BIOS
        run_dialog HAS_SEP_BOOT yesno "Separate /boot?" "Do you have a separate /boot partition?" || handle_error "/boot choice cancelled."
        if [[ "$HAS_SEP_BOOT" == "yes" ]]; then
            run_dialog BOOT_PARTITION_DEVICE radiolist "Boot Partition" "Select your /boot partition:" $all_parts || handle_error "/boot selection cancelled."
            [[ -z "$BOOT_PARTITION_DEVICE" ]] && handle_error "/boot partition not specified."
        fi
    fi

    # Get swap
    run_dialog SWAP_CHOICE_MANUAL radiolist "Swap Configuration" "How do you want to configure swap?" \
        "none" "No swap" "on" \
        "partition" "Use a swap partition" "off" \
        "file" "Create a swap file later (via Ansible)" "off" || handle_error "Swap choice cancelled."
    SWAP_CHOICE="$SWAP_CHOICE_MANUAL"
    if [[ "$SWAP_CHOICE" == "partition" ]]; then
        run_dialog SWAP_DEVICE_OR_SIZE radiolist "Swap Partition" "Select your SWAP partition:" $all_parts || handle_error "Swap partition selection cancelled."
        [[ -z "$SWAP_DEVICE_OR_SIZE" ]] && handle_error "Swap partition not specified."
    elif [[ "$SWAP_CHOICE" == "file" ]]; then
        run_dialog SWAP_DEVICE_OR_SIZE input "Swap File Size" "Enter size for swap file (e.g., 2G, 4096M):" "2G" || handle_error "Swap file size cancelled."
    fi

    # LUKS for manually selected root
    ROOT_PARTITION_DEVICE="$ROOT_PART_RAW" # Tentative, might become mapper device
    if [[ "$LUKS_ENABLED" == "true" ]]; then
        run_dialog CONFIRM_LUKS_MANUAL yesno "LUKS on Manual Root" "Encrypt $ROOT_PART_RAW with LUKS ($LUKS_PASSWORD)?" || handle_error "LUKS confirmation for manual root cancelled."
        if [[ "$CONFIRM_LUKS_MANUAL" == "yes" ]]; then
            log "Setting up LUKS on $ROOT_PART_RAW (manual)..."
            echo -n "$LUKS_PASSWORD" | cryptsetup luksFormat --type luks2 "$ROOT_PART_RAW" -d - $LUKS_OPTIONS || handle_error "LUKS format failed on $ROOT_PART_RAW."
            echo -n "$LUKS_PASSWORD" | cryptsetup open "$ROOT_PART_RAW" "$LUKS_ROOT_MAPPER_NAME" -d - || handle_error "LUKS open failed for $ROOT_PART_RAW."
            ROOT_PARTITION_DEVICE="/dev/mapper/$LUKS_ROOT_MAPPER_NAME"
        else
            log "Skipping LUKS on manual root partition as per user choice."
            LUKS_ENABLED="false" # User opted out for this specific partition
        fi
    fi

    # LVM for manually selected (possibly LUKS) device
    # At this point, ROOT_PARTITION_DEVICE holds the user-selected root partition,
    # or the LUKS mapper if LUKS was enabled on that selection.
    local device_for_lvm_or_fs="$ROOT_PARTITION_DEVICE"

    if [[ "$LVM_ENABLED" == "true" ]]; then
        log "LVM is enabled by user choice. Setting up LVM on $device_for_lvm_or_fs (manual flow)..."
        # The LVM configuration (VG name, LV names/sizes) was gathered in gather_install_parameters.
        _setup_lvm_on_device "$device_for_lvm_or_fs"
        # _setup_lvm_on_device updates global ROOT_PARTITION_DEVICE to the LVM LV path for root.
        # It also handles formatting/mounting Home LV and creating/activating Swap LV if configured.
        log "LVM setup complete (manual flow). Global ROOT_PARTITION_DEVICE is now $ROOT_PARTITION_DEVICE"
    else
        # If LVM is not enabled, ROOT_PARTITION_DEVICE remains as the user-selected (possibly LUKS-mapped) device.
        log "LVM not enabled by user choice (manual flow). ROOT_PARTITION_DEVICE for formatting is $ROOT_PARTITION_DEVICE"
    fi
    # The subsequent "Formatting and Mounting" section will use the final ROOT_PARTITION_DEVICE.

    # Formatting and Mounting
    if [[ -n "$BOOT_PARTITION_DEVICE" ]]; then
        local boot_fs_type="fat32"
        if [[ "$FIRMWARE_TYPE" == "BIOS" ]]; then boot_fs_type="ext4"; fi # Or ext2, ext3
        run_dialog FORMAT_BOOT yesno "Format Boot" "Format $BOOT_PARTITION_DEVICE as $boot_fs_type?" || handle_error "Boot format choice cancelled."
        if [[ "$FORMAT_BOOT" == "yes" ]]; then
            if [[ "$FIRMWARE_TYPE" == "UEFI" ]]; then log_cmd "mkfs.fat -F32 $BOOT_PARTITION_DEVICE" || handle_error "mkfs.fat failed on $BOOT_PARTITION_DEVICE."; else log_cmd "mkfs.$boot_fs_type -F $BOOT_PARTITION_DEVICE" || handle_error "mkfs.$boot_fs_type failed on $BOOT_PARTITION_DEVICE."; fi
        fi
    fi

    run_dialog FORMAT_ROOT yesno "Format Root" "Format $ROOT_PARTITION_DEVICE as $ROOT_FS_TYPE?" || handle_error "Root format choice cancelled."
    if [[ "$FORMAT_ROOT" == "yes" ]]; then
        format_and_mount_root "$ROOT_PARTITION_DEVICE" # This handles BTRFS subvolumes too
    else
        log "Skipping format of $ROOT_PARTITION_DEVICE."
        if [[ "$ROOT_FS_TYPE" == "btrfs" ]]; then
            log "Selected root is BTRFS and will not be formatted. Checking subvolume configuration for $ROOT_PARTITION_DEVICE."
            local USE_CUSTOM_SUBVOLS
            run_dialog USE_CUSTOM_SUBVOLS yesno "Custom BTRFS Subvolumes" \
                "Your existing BTRFS root ($ROOT_PARTITION_DEVICE) will not be formatted.\nDo you want to specify custom subvolume names for mounting / (root), /home, and /var?" || handle_error "Custom BTRFS subvolume choice cancelled."

            if [[ "$USE_CUSTOM_SUBVOLS" == "yes" ]]; then
                local CUSTOM_ROOT_SUBVOL=""
                local CUSTOM_HOME_SUBVOL=""
                local CUSTOM_VAR_SUBVOL=""

                run_dialog CUSTOM_ROOT_SUBVOL input "Root Subvolume (/)" \
                    "Enter the name of the BTRFS subvolume for / (root).\nDefault: @\nLeave BLANK to use the top-level BTRFS volume for /." "@" || handle_error "Root subvolume entry cancelled."
                run_dialog CUSTOM_HOME_SUBVOL input "Home Subvolume (/home)" \
                    "Enter the name of the BTRFS subvolume for /home.\nDefault: @home\nLeave BLANK if /home should be part of the root subvolume or top-level." "@home" || handle_error "Home subvolume entry cancelled."
                run_dialog CUSTOM_VAR_SUBVOL input "Var Subvolume (/var)" \
                    "Enter the name of the BTRFS subvolume for /var.\nDefault: @var\nLeave BLANK if /var should be part of the root subvolume or top-level." "@var" || handle_error "/var subvolume entry cancelled."

                local BTRFS_TMP_MOUNT="/mnt/btrfs_tmp_check_$$"
                log_cmd "mkdir -p $BTRFS_TMP_MOUNT" || handle_error "Failed to create temporary BTRFS mount point $BTRFS_TMP_MOUNT."
                log_cmd "mount -o ro $ROOT_PARTITION_DEVICE $BTRFS_TMP_MOUNT" || { rmdir "$BTRFS_TMP_MOUNT" &>/dev/null; handle_error "Failed to mount $ROOT_PARTITION_DEVICE to $BTRFS_TMP_MOUNT for subvolume check."; }

                # Mount Root
                if [[ -n "$CUSTOM_ROOT_SUBVOL" ]]; then
                    log "Checking for custom root subvolume '$CUSTOM_ROOT_SUBVOL' on $ROOT_PARTITION_DEVICE..."
                    if ! btrfs subvolume list -o "$BTRFS_TMP_MOUNT" | grep -qE "[[:space:]]path ${CUSTOM_ROOT_SUBVOL}$"; then
                        log_cmd "umount $BTRFS_TMP_MOUNT"
                        rmdir "$BTRFS_TMP_MOUNT" &>/dev/null
                        handle_error "Specified root subvolume '$CUSTOM_ROOT_SUBVOL' not found on $ROOT_PARTITION_DEVICE."
                    fi
                    log "Mounting custom root subvolume '$CUSTOM_ROOT_SUBVOL' to /mnt..."
                    log_cmd "mount -o subvol=$CUSTOM_ROOT_SUBVOL,compress=zstd $ROOT_PARTITION_DEVICE /mnt" || handle_error "Failed to mount custom root subvolume '$CUSTOM_ROOT_SUBVOL'."
                    BTRFS_SUBVOLUMES_ENABLED="true"
                else
                    log "Mounting top-level BTRFS volume of $ROOT_PARTITION_DEVICE to /mnt..."
                    log_cmd "mount -o compress=zstd $ROOT_PARTITION_DEVICE /mnt" || handle_error "Failed to mount top-level BTRFS from $ROOT_PARTITION_DEVICE."
                    BTRFS_SUBVOLUMES_ENABLED="false"
                fi

                # Mount Home
                if [[ -n "$CUSTOM_HOME_SUBVOL" ]]; then
                    log "Checking for custom home subvolume '$CUSTOM_HOME_SUBVOL' on $ROOT_PARTITION_DEVICE..."
                    if ! btrfs subvolume list -o "$BTRFS_TMP_MOUNT" | grep -qE "[[:space:]]path ${CUSTOM_HOME_SUBVOL}$"; then
                        log_cmd "umount $BTRFS_TMP_MOUNT"
                        rmdir "$BTRFS_TMP_MOUNT" &>/dev/null
                        handle_error "Specified home subvolume '$CUSTOM_HOME_SUBVOL' not found on $ROOT_PARTITION_DEVICE."
                    fi
                    log "Mounting custom home subvolume '$CUSTOM_HOME_SUBVOL' to /mnt/home..."
                    log_cmd "mkdir -p /mnt/home" || handle_error "Failed to create /mnt/home directory."
                    log_cmd "mount -o subvol=$CUSTOM_HOME_SUBVOL,compress=zstd $ROOT_PARTITION_DEVICE /mnt/home" || handle_error "Failed to mount custom home subvolume '$CUSTOM_HOME_SUBVOL'."
                else
                    log "Custom home subvolume not specified. /home will be part of the root filesystem."
                fi

                # Mount Var
                if [[ -n "$CUSTOM_VAR_SUBVOL" ]]; then
                    log "Checking for custom var subvolume '$CUSTOM_VAR_SUBVOL' on $ROOT_PARTITION_DEVICE..."
                    if ! btrfs subvolume list -o "$BTRFS_TMP_MOUNT" | grep -qE "[[:space:]]path ${CUSTOM_VAR_SUBVOL}$"; then
                        log_cmd "umount $BTRFS_TMP_MOUNT"
                        rmdir "$BTRFS_TMP_MOUNT" &>/dev/null
                        handle_error "Specified /var subvolume '$CUSTOM_VAR_SUBVOL' not found on $ROOT_PARTITION_DEVICE."
                    fi
                    log "Mounting custom var subvolume '$CUSTOM_VAR_SUBVOL' to /mnt/var..."
                    log_cmd "mkdir -p /mnt/var" || handle_error "Failed to create /mnt/var directory."
                    log_cmd "mount -o subvol=$CUSTOM_VAR_SUBVOL,compress=zstd $ROOT_PARTITION_DEVICE /mnt/var" || handle_error "Failed to mount custom var subvolume '$CUSTOM_VAR_SUBVOL'."
                else
                    log "Custom /var subvolume not specified. /var will be part of the root filesystem."
                fi

                log_cmd "umount $BTRFS_TMP_MOUNT" || log "Warning: Failed to unmount temporary BTRFS check mount $BTRFS_TMP_MOUNT."
                rmdir "$BTRFS_TMP_MOUNT" &>/dev/null || log "Warning: Failed to remove temporary BTRFS check directory $BTRFS_TMP_MOUNT."
                log "Custom BTRFS subvolume mounting process complete."

            else # Auto-detect standard subvolumes
                log "Attempting to auto-detect and mount standard BTRFS subvolumes (@, @home) from $ROOT_PARTITION_DEVICE."
                log_cmd "mount $ROOT_PARTITION_DEVICE /mnt" || handle_error "Failed to mount BTRFS top-level $ROOT_PARTITION_DEVICE for auto-detection."

                local found_at_subvol="false"
                local found_athome_subvol="false"

                if btrfs subvolume list -o /mnt | grep -qE '[[:space:]]path @$'; then
                    found_at_subvol="true"
                    log "Standard '@' subvolume detected."
                fi
                if btrfs subvolume list -o /mnt | grep -qE '[[:space:]]path @home$'; then
                    found_athome_subvol="true"
                    log "Standard '@home' subvolume detected."
                fi

                if [[ "$found_at_subvol" == "true" ]]; then
                    log "Remounting with '@' subvolume as root."
                    log_cmd "umount /mnt" || handle_error "Failed to unmount BTRFS top-level for @ subvolume remount."
                    log_cmd "mount -o subvol=@,compress=zstd $ROOT_PARTITION_DEVICE /mnt" || handle_error "Failed to mount '@' subvolume."
                    BTRFS_SUBVOLUMES_ENABLED="true"

                    if [[ "$found_athome_subvol" == "true" ]]; then
                        log "Mounting '@home' subvolume."
                        log_cmd "mkdir -p /mnt/home" || handle_error "Failed to create /mnt/home for @home subvolume."
                        log_cmd "mount -o subvol=@home,compress=zstd $ROOT_PARTITION_DEVICE /mnt/home" || handle_error "Failed to mount '@home' subvolume."
                    else
                        log "'@home' subvolume not detected. /home will be part of '@' subvolume."
                    fi
                else
                    log "Standard '@' subvolume not detected. Using BTRFS top-level as root. /home will be part of the top-level filesystem."
                    BTRFS_SUBVOLUMES_ENABLED="false"
                fi
                log "BTRFS auto-detection and mounting process complete."
            fi
        else # Not BTRFS, just mount it as is
            log "Mounting non-BTRFS $ROOT_PARTITION_DEVICE as is to /mnt."
            log_cmd "mount $ROOT_PARTITION_DEVICE /mnt" || handle_error "Failed to mount existing root $ROOT_PARTITION_DEVICE."
        fi
    fi


    if [[ -n "$BOOT_PARTITION_DEVICE" ]]; then
        log_cmd "mkdir -p /mnt/boot" || handle_error "mkdir /mnt/boot failed."
        log_cmd "mount $BOOT_PARTITION_DEVICE /mnt/boot" || handle_error "Mount $BOOT_PARTITION_DEVICE to /mnt/boot failed."
    fi

    if [[ "$SWAP_CHOICE" == "partition" && -n "$SWAP_DEVICE_OR_SIZE" ]]; then
        run_dialog FORMAT_SWAP yesno "Format Swap" "Format $SWAP_DEVICE_OR_SIZE as swap?" || handle_error "Swap format choice cancelled."
        if [[ "$FORMAT_SWAP" == "yes" ]]; then log_cmd "mkswap $SWAP_DEVICE_OR_SIZE" || handle_error "mkswap failed on $SWAP_DEVICE_OR_SIZE."; fi
        log_cmd "swapon $SWAP_DEVICE_OR_SIZE" || handle_error "swapon failed for $SWAP_DEVICE_OR_SIZE."
    fi
    log "Manual partitioning setup complete."
}
_setup_lvm_on_device() {
    local pv_device="$1"
    log "Initializing LVM on $pv_device..."

    log_cmd "pvcreate -ff --yes $pv_device" || handle_error "LVM: pvcreate failed on $pv_device."
    log_cmd "vgcreate $LVM_VG_NAME $pv_device" || handle_error "LVM: vgcreate $LVM_VG_NAME failed."

    log "Creating LVM Root LV: $LVM_LV_ROOT_NAME ($LVM_LV_ROOT_SIZE)"
    log_cmd "lvcreate --yes -n $LVM_LV_ROOT_NAME -L $LVM_LV_ROOT_SIZE $LVM_VG_NAME" || handle_error "LVM: lvcreate $LVM_LV_ROOT_NAME failed."
    ROOT_PARTITION_DEVICE="/dev/$LVM_VG_NAME/$LVM_LV_ROOT_NAME" # Update global

    if [[ "$LVM_LV_HOME_ENABLED" == "true" ]]; then
        log "Creating LVM Home LV: $LVM_LV_HOME_NAME ($LVM_LV_HOME_SIZE)"
        log_cmd "lvcreate --yes -n $LVM_LV_HOME_NAME -L $LVM_LV_HOME_SIZE $LVM_VG_NAME" || handle_error "LVM: lvcreate $LVM_LV_HOME_NAME failed."
        local home_lv_path="/dev/$LVM_VG_NAME/$LVM_LV_HOME_NAME"
        log "Formatting Home LV $home_lv_path as $LVM_LV_HOME_FSTYPE..."
        # Ensure LVM_LV_HOME_FSTYPE is set (it defaults to ROOT_FS_TYPE in gather_params)
        if [[ -z "$LVM_LV_HOME_FSTYPE" ]]; then LVM_LV_HOME_FSTYPE="$ROOT_FS_TYPE"; fi
        log_cmd "mkfs.$LVM_LV_HOME_FSTYPE -F $home_lv_path" || handle_error "LVM: mkfs for Home LV $home_lv_path failed."
        log_cmd "mkdir -p /mnt/home" || handle_error "LVM: mkdir /mnt/home failed."
        log_cmd "mount $home_lv_path /mnt/home" || handle_error "LVM: mount Home LV $home_lv_path failed."
    fi

    if [[ "$LVM_LV_SWAP_ENABLED" == "true" ]]; then
        log "Creating LVM Swap LV: $LVM_LV_SWAP_NAME ($LVM_LV_SWAP_SIZE)"
        log_cmd "lvcreate --yes -n $LVM_LV_SWAP_NAME -L $LVM_LV_SWAP_SIZE $LVM_VG_NAME" || handle_error "LVM: lvcreate $LVM_LV_SWAP_NAME failed."
        SWAP_DEVICE_OR_SIZE="/dev/$LVM_VG_NAME/$LVM_LV_SWAP_NAME" # Update global
        log "Formatting Swap LV $SWAP_DEVICE_OR_SIZE..."
        log_cmd "mkswap $SWAP_DEVICE_OR_SIZE" || handle_error "LVM: mkswap for Swap LV $SWAP_DEVICE_OR_SIZE failed."
        log_cmd "swapon $SWAP_DEVICE_OR_SIZE" || handle_error "LVM: swapon for Swap LV $SWAP_DEVICE_OR_SIZE failed."
    fi
    log "LVM setup on $pv_device complete. Root LV is $ROOT_PARTITION_DEVICE."
}


setup_disk() {
    log "Setting up disk: $TARGET_DISK based on scheme: $PARTITION_SCHEME, FS: $ROOT_FS_TYPE"
    cleanup # Ensure clean state

    if [[ "$PARTITION_SCHEME" == "auto_"* ]]; then # Covers auto_gpt and auto_mbr
        log "Wiping filesystem signatures on $TARGET_DISK for automatic partitioning..."
        log_cmd "wipefs -af $TARGET_DISK" || log "Warn: wipefs on $TARGET_DISK failed. Potential remnants."
        # sgdisk --zap-all is more thorough for GPT remnants
        log_cmd "sgdisk --zap-all $TARGET_DISK" || log "Warn: sgdisk zap-all on $TARGET_DISK failed."
    fi

    case "$PARTITION_SCHEME" in
        "auto_gpt") auto_partition_gpt_uefi ;;
        "auto_mbr") auto_partition_mbr_bios ;;
        "manual_gpt" | "manual_mbr") manual_partition_flow ;;
        *) handle_error "Unknown partitioning scheme: $PARTITION_SCHEME" ;;
    esac


    log "Disk setup process finished."
    save_checkpoint "disk_setup_complete"
}

install_base_system() {
    log "Installing base system..."
    local pacstrap_pkgs_array=("base" "base-devel" "$KERNEL_CHOICE" "linux-firmware" "ansible" "sudo" "vim" "git")
    # Add network manager based on a variable (e.g., NETWORK_CONFIG_TYPE set in gather_parameters)
    # For now, hardcoding NetworkManager as it's common and was in original pacstrap.
    pacstrap_pkgs_array+=("networkmanager")
    # Add user selected packages
    if [[ -n "$ADDITIONAL_PACKAGES_STRING" ]]; then
        read -r -a user_pkgs <<< "$ADDITIONAL_PACKAGES_STRING"
        pacstrap_pkgs_array+=("${user_pkgs[@]}")
    fi
    # Remove duplicates just in case
    local final_pacstrap_pkgs
    final_pacstrap_pkgs=$(echo "${pacstrap_pkgs_array[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')

    log_cmd "pacstrap -K /mnt $final_pacstrap_pkgs" || handle_error "Pacstrap failed."
    log "Base system installed. fstab generation will be handled by Ansible."
    # log_cmd "genfstab -U /mnt >> /mnt/etc/fstab" || handle_error "genfstab failed." # Removed: Ansible will handle fstab
    save_checkpoint "base_system_installed"
}

generate_ansible_vars() {
    log "Generating Ansible variables file: $ANS_VARS_FILE"
    mkdir -p "$(dirname "$ANS_VARS_FILE")"
    local ansible_additional_packages_yaml="[]"
    if [[ -n "$ADDITIONAL_PACKAGES_STRING" ]]; then
        ansible_additional_packages_yaml="\n$(echo "$ADDITIONAL_PACKAGES_STRING" | sed 's/ /\n      - /g' | sed 's/^/      - /')"
    fi

    cat > "$ANS_VARS_FILE" <<EOF
---
# Ansible variables generated by installer_new.sh
dist_name: "$DIST_NAME"
firmware_type: "$FIRMWARE_TYPE"
target_disk: "$TARGET_DISK"
partition_scheme: "$PARTITION_SCHEME"
# These are the devices *before* potential LVM mapping for root. Ansible might need physical device for LVM role.
raw_root_partition_device: "$ROOT_PARTITION_DEVICE" # Could be /dev/sdaX or /dev/mapper/cryptroot if LUKS is on raw part
raw_boot_partition_device: "$BOOT_PARTITION_DEVICE"
root_fs_type: "$ROOT_FS_TYPE"
btrfs_subvolumes_enabled: $BTRFS_SUBVOLUMES_ENABLED
swap_choice: "$SWAP_CHOICE"
swap_device_or_size: "$SWAP_DEVICE_OR_SIZE" # If 'file', this is size like "2G"

luks_enabled: $LUKS_ENABLED
luks_password: "${LUKS_PASSWORD}" # VAULT THIS
luks_root_mapper_name: "$LUKS_ROOT_MAPPER_NAME"
luks_options: "$LUKS_OPTIONS"

lvm_enabled: $LVM_ENABLED
lvm_vg_name: "$LVM_VG_NAME"
# lvm_pvs: is not explicitly tracked as a separate list currently,
# as our simple LVM assumes the PV is the device passed to _setup_lvm_on_device.
# This could be derived from raw_root_partition_device if needed by an Ansible LVM role.
lvm_lvs: |
  - name: ${LVM_LV_ROOT_NAME}
    size: ${LVM_LV_ROOT_SIZE}
    mountpoint: /
    fstype: ${ROOT_FS_TYPE} # The root LV will always use the selected ROOT_FS_TYPE
$(if [[ "$LVM_LV_HOME_ENABLED" == "true" ]]; then
  echo "  - name: ${LVM_LV_HOME_NAME}"
  echo "    size: ${LVM_LV_HOME_SIZE}"
  echo "    mountpoint: /home"
  echo "    fstype: ${LVM_LV_HOME_FSTYPE:-$ROOT_FS_TYPE}" # Default to ROOT_FS_TYPE if not set
fi)
$(if [[ "$LVM_LV_SWAP_ENABLED" == "true" ]]; then
  echo "  - name: ${LVM_LV_SWAP_NAME}"
  echo "    size: ${LVM_LV_SWAP_SIZE}"
  echo "    fstype: swap" # Swap LVs are always 'swap' fstype
fi)

hostname: "$HOSTNAME"
username: "$USERNAME"
user_password: "${USER_PASSWORD}" # VAULT THIS
root_password: "${ROOT_PASSWORD}" # VAULT THIS
timezone: "$TIMEZONE"
locale: "$LOCALE"
keymap: "$KEYMAP"
console_keymap: "$CONSOLE_KEYMAP"

kernel_choice: "$KERNEL_CHOICE"
bootloader_choice: "$BOOTLOADER_CHOICE"
wm_de_choice: "$WM_DE_CHOICE"
# network_config_type: "$NETWORK_CONFIG_TYPE" # e.g. NetworkManager or iwd

additional_packages_list: ${ansible_additional_packages_yaml}

# services_to_enable: # Example, Ansible can have defaults
#   - sshd
#   - NetworkManager.service # if chosen
#   - bluetooth.service # if bluez installed
# install_aur_helper: true # Example
EOF
    log_cmd "chmod 600 $ANS_VARS_FILE" || handle_error "Failed to set permissions on $ANS_VARS_FILE"
    log "Ansible variables file generated."
    save_checkpoint "ansible_vars_generated"
}

copy_ansible_playbooks() {
    log "Copying Ansible playbooks from $ANS_PLAYBOOK_DIR_HOST to $ANS_PLAYBOOK_DIR_TARGET..."
    local effective_source_dir="$ANS_PLAYBOOK_DIR_HOST"
    if [ ! -d "$effective_source_dir" ]; then
        local script_dir; script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
        if [ -d "$script_dir/$ANS_PLAYBOOK_DIR_HOST" ]; then effective_source_dir="$script_dir/$ANS_PLAYBOOK_DIR_HOST";
        elif [ -d "/usr/local/share/$DIST_NAME/ansible_setup" ]; then effective_source_dir="/usr/local/share/$DIST_NAME/ansible_setup";
        else handle_error "Ansible playbook source dir '$ANS_PLAYBOOK_DIR_HOST' not found (checked CWD, script dir, share dir)."; fi
    fi
    log "Using Ansible playbook source: $effective_source_dir"
    mkdir -p "$ANS_PLAYBOOK_DIR_TARGET" || handle_error "Failed to create target Ansible directory $ANS_PLAYBOOK_DIR_TARGET."
    log_cmd "cp -rT \"$effective_source_dir/\" \"$ANS_PLAYBOOK_DIR_TARGET/\"" || handle_error "Failed to copy Ansible playbooks."
    log "Ansible playbooks copied."
    save_checkpoint "ansible_playbooks_copied"
}

run_ansible_configuration() {
    log "Running Ansible configuration..."
    local ansible_cmd="ansible-playbook $MAIN_PLAYBOOK"
    log_cmd "arch-chroot /mnt /bin/bash -c 'cd /root/ansible_setup && $ansible_cmd'" || handle_error "Ansible playbook execution failed. Check $INSTALL_LOG and /mnt/var/log/ansible_setup/ansible_run.log (inside chroot)."
    log "Ansible configuration complete."
    save_checkpoint "ansible_configuration_complete"
}

post_install_cleanup() {
    log "Performing post-installation cleanup..."
    cleanup
    rm -f "$CHECKPOINT_FILE" "${CHECKPOINT_FILE}.vars"
    log "Cleanup complete."
    run_dialog "" msgbox "Installation Complete" "$DIST_NAME installation is complete!\n\nYou can now reboot your system." || true
}

# --- Main Execution ---
main() {
    >"$INSTALL_LOG"
    log "Starting $DIST_NAME Installer (New Version)..."
    if [[ $EUID -ne 0 ]]; then handle_error "This script must be run as root."; fi
    trap 'echo; run_dialog CONFIRM_EXIT yesno "Confirm Exit" "Are you sure you want to exit the installer?" || main; cleanup; exit 130' INT
    if ! command -v dialog >/dev/null 2>&1; then echo "ERROR: 'dialog' command not found. Please install the 'dialog' package." >&2; exit 1; fi

    local deps=("parted" "cryptsetup" "lvm" "pacstrap" "arch-chroot" "lsblk" "reflector" "sgdisk" "wipefs" "mkfs.fat" "mkfs.btrfs" "btrfs")
    # Add other mkfs variants like mkfs.ext4, mkfs.xfs if they are not typically part of a 'coreutils' or 'e2fsprogs' type package already expected.
    # Assuming common mkfs tools are generally available if base utilities are.
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            # No dialog here as dialog itself is checked above. Error directly.
            log "FATAL ERROR: Required command '$dep' not found. Please install it and try again."
            echo "FATAL ERROR: Required command '$dep' not found. Please install it and try again." >&2
            exit 1
        fi
    done
    log "All essential command dependencies met."

    load_checkpoint
    if [[ "$current_step" < "parameters_gathered" ]]; then gather_install_parameters || handle_error "Failed: gather_install_parameters"; fi
    if [[ "$current_step" < "disk_setup_complete" ]]; then setup_disk || handle_error "Failed: setup_disk"; fi
    if [[ "$current_step" < "base_system_installed" ]]; then install_base_system || handle_error "Failed: install_base_system"; fi
    if [[ "$current_step" < "ansible_vars_generated" ]]; then generate_ansible_vars || handle_error "Failed: generate_ansible_vars"; fi
    if [[ "$current_step" < "ansible_playbooks_copied" ]]; then copy_ansible_playbooks || handle_error "Failed: copy_ansible_playbooks"; fi
    if [[ "$current_step" < "ansible_configuration_complete" ]]; then run_ansible_configuration; fi # Error handled within

    post_install_cleanup
    log "$DIST_NAME Installer finished successfully."
    echo -e "\nInstallation finished. Please check $INSTALL_LOG for details."
    echo "You can now reboot. Type 'reboot'."
}

main "$@"