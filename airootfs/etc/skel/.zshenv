export UU_ORDER="$UU_ORDER:~/.zshenv"

unset _old_path

if systemd-detect-virt -q; then
	# if the system is running inside a virtual machine, disable hardware cursors
	export WLR_NO_HARDWARE_CURSORS=1
fi

if [ -x "$(command -v most)" ]; then
PAGER=most
fi

# gum options
export GUM_SPIN_SPINNER="pulse"
export GUM_SPIN_ALIGN="right"
export GUM_SPIN_SHOW_OUTPUT=true
export GUM_SPIN_SPINNER_FOREGROUND=033
export GUM_SPIN_TITLE_FOREGROUND=024

export GUM_CHOOSE_CURSOR="> "
export GUM_CHOOSE_CURSOR_PREFIX="[ ] "
export GUM_CHOOSE_SELECTED_PREFIX="[✓] "
export GUM_CHOOSE_UNSELECTED_PREFIX="[ ] "
export GUM_CHOOSE_CURSOR_FOREGROUND=046
export GUM_CHOOSE_ITEM_FOREGROUND=045
export GUM_CHOOSE_SELECTED_FOREGROUND=027

export GUM_CONFIRM_PROMPT_FOREGROUND=027
export GUM_CONFIRM_SELECTED_FOREGROUND=064
export GUM_CONFIRM_UNSELECTED_FOREGROUND=010

# fzf options
export FZF_BASE=/usr/share/fzf
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS' --color='bg:#141414,bg+:#3F3F3F,info:#BDBB72,border:#6B6B6B,spinner:#98BC99' --color='hl:#719872,fg:#bbb12a,header:#719872,fg+:#D9D9D9' --color='pointer:#E12672,marker:#E17899,prompt:#98BEDE,hl+:#98BC99''

[[ -f ~/.zshenv.local ]] && source ~/.zshenv.local

