export UU_ORDER="$UU_ORDER:~/.zprofile"

echo $PATH | grep -q "$HOME/.local/bin:" || export PATH="$HOME/.local/bin:$PATH"

if [ -d $HOME/.cargo/bin ]; then
  PATH="$PATH:$HOME/.cargo/bin"
fi

if [ -d $HOME/Utils/bin ]; then
  PATH="$PATH:$HOME/Utils/bin"
fi

export -U PATH
