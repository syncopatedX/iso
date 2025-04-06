#!/usr/bin/env bash

## Author : Aditya Shakya (adi1090x)
## Github : @adi1090x
#
## Rofi   : Launcher (Modi Drun, Run, File Browser, Window)

dir="$HOME/.config/rofi/launchers/type-3"
theme="style-4"

## Run
rofi \
    -no-lazy-grab \
    -show drun \
    -modi run,drun,window \
    -theme ${dir}/${theme}.rasi
