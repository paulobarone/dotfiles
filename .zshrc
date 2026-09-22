export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  tmuxinator
  copyfile
  docker
  docker-compose
  extract
)

source $ZSH/oh-my-zsh.sh

alias ls="eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions"

eval "$(starship init zsh)"

cd ~/Projects

export EDITOR="code"

bindkey '^H' backward-delete-word
bindkey '^[[3;5~' kill-word
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word