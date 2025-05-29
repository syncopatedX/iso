#!/bin/bash

#shellcheck disable=2016

begin=$(date +%s)

if ! hash mkarchiso curl >/dev/null 2>&1; then
	echo "${0##*/}: error: one or more missing packages: archiso curl"
	exit 1
fi

while getopts ":hLRt:" OPT; do
	case "$OPT" in
	h)
		echo
		echo "Usage: ${0##*/} [-hutLR]"
		echo
		echo "    -h           Print this message and exit"
		echo "    -L           Use the LTS kernel instead of vanilla"
		echo "    -R           Use the Realtime-LTS kernel instead of vanilla"
		echo
		exit 0
		;;
	L)
		echo "Enabling LTS"
		sleep 0.5
		sed -i 's/^broadcom-wl$/broadcom-wl-dkms/g' packages.x86_64
		sed -i '/^linux$/ a linux-lts-headers' packages.x86_64
		sed -i 's/^linux$/linux-lts/g' packages.x86_64
		sed -i 's/-linux/-linux-lts/g' efiboot/loader/entries/*
		sed -i 's/-linux/-linux-lts/g' syslinux/*.cfg
		sed -i 's/-linux/-linux-lts/g' grub/grub.cfg
		sed -i 's/-linux/-linux-lts/g' airootfs/etc/mkinitcpio.d/linux.preset
		sed -i 's/"syncopated"/"syncopated-lts"/g' profiledef.sh

		lts=true
		;;
	R)
		echo "Enabling Realtime-LTS"
		sleep 0.5
		sed -i 's/^broadcom-wl$/broadcom-wl-dkms/g' packages.x86_64
		sed -i '/^linux$/ a linux-rt-lts-headers' packages.x86_64
		sed -i 's/^linux$/linux-rt-lts/g' packages.x86_64
		sed -i 's/-linux/-linux-rt-lts/g' efiboot/loader/entries/*
		sed -i 's/-linux/-linux-rt-lts/g' syslinux/*.cfg
		sed -i 's/-linux/-linux-rt-lts/g' grub/grub.cfg
		sed -i 's/-linux/-linux-rt-lts/g' airootfs/etc/mkinitcpio.d/linux.preset
		sed -i 's/"syncopated"/"syncopated-rt-lts"/g' profiledef.sh

		rt=true
		;;
	:)
		echo "${0##*/}: error: -$OPTARG requires an argument: <PATH_TO_INSTALLER>"
		exit 1
		;;
	*)
		echo "${0##*/}: error: invalid flag '$OPT' -- use -h for options"
		exit 1
		;;
	esac
done
shift $((OPTIND - 1))

# update os-release and lsb-release
[[ -e airootfs/etc/os-release ]] && sed -i "s/\(VERSION_ID\)=.*/\1=$(date +%Y.%m.%d)/g" airootfs/etc/os-release
[[ -e airootfs/etc/lsb-release ]] && sed -i "s/\(DISTRIB_RELEASE\)=.*/\1=$(date +%Y.%m.%d)/g" airootfs/etc/lsb-release

# if [ ! -d "/home/repository" ]; then
# 	cp -r ./repository /home/
# else
# 	rm -rf ./home/repository
# 	cp -r ./repository /home/
# fi

# build it
mkarchiso -m iso -v .

# clean up
rm -rf work

if [[ $lts == 'true' ]]; then
	sed -i 's/^broadcom-wl-dkms$/broadcom-wl/g' packages.x86_64
	sed -i '/linux-lts-headers/d' packages.x86_64
	sed -i 's/^linux-lts$/linux/g' packages.x86_64
	sed -i 's/-linux-lts/-linux/g' efiboot/loader/entries/*
	sed -i 's/-linux-lts/-linux/g' syslinux/*.cfg
	sed -i 's/-linux-lts/-linux/g' grub/grub.cfg
	sed -i 's/-linux-lts/-linux/g' airootfs/etc/mkinitcpio.d/linux.preset
	sed -i 's/syncopated-lts/syncopated/g' profiledef.sh
elif [[ $rt == 'true' ]]; then
	sed -i 's/^broadcom-wl-dkms$/broadcom-wl/g' packages.x86_64
	sed -i '/linux-rt-lts-headers/d' packages.x86_64
	sed -i 's/^linux-rt-lts$/linux/g' packages.x86_64
	sed -i 's/-linux-rt-lts/-linux/g' efiboot/loader/entries/*
	sed -i 's/-linux-rt-lts/-linux/g' syslinux/*.cfg
	sed -i 's/-linux-rt-lts/-linux/g' grub/grub.cfg
	sed -i 's/-linux-rt-lts/-linux/g' airootfs/etc/mkinitcpio.d/linux.preset
	sed -i 's/syncopated-rt-lts/syncopated/g' profiledef.sh
fi

end=$(date +%s)
echo "build took $(((end - begin) / 60))m $(((end - begin) % 60))s"
