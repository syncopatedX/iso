#!/bin/sh

if [ -d /etc/X11/xinit/xinitrc.d ]; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh; do
        [ -x "$f" ] && . "$f"
    done
fi

[ -r /etc/X11/xinit/.Xmodmap ] && xmodmap /etc/X11/xinit/.Xmodmap
[ -r ~/.Xmodmap ] && xmodmap ~/.Xmodmap
[ -r ~/.Xresources ] && xrdb -merge ~/.Xresources

export XDG_CONFIG_HOME="$HOME/.config"
export PATH="$HOME/.local/bin:$PATH"

# If in a live ISO session (i.e., /run/archiso exists)
# and NetworkManager is not already active, then attempt to start it.
if [ -d /run/archiso ] && ! systemctl is-active --quiet NetworkManager.service; then
  systemctl start NetworkManager
  nmcli connection modify "Wired Connection 1" ipv6.method disabled
  systemctl restart NetworkManager
fi

pulseaudio &
nitrogen --restore &
xset dpms 600 900 1200
xset r rate 350 60

exec i3
