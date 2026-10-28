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

# Homebrew no fim do PATH (pacotes da distro têm prioridade)
if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
  export HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
  export HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX/Homebrew"
  export PATH="$PATH:$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin"
  export MANPATH="${MANPATH:-}:$HOMEBREW_PREFIX/share/man"
fi

# Pacotes globais do npm (instalados sem sudo)
export PATH="$HOME/.npm-global/bin:$PATH"

source $ZSH/oh-my-zsh.sh

alias ls="eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions"

eval "$(starship init zsh)"

cd ~/Projects

export EDITOR="micro"
export MICRO_TRUECOLOR=1

# bat usa as cores do tema do terminal (acompanha o atheme)
export BAT_THEME="ansi"

# Palavras param em / - . _ etc. (Ctrl+Backspace, Ctrl+Delete, Ctrl+setas)
WORDCHARS=''

bindkey '^[[3;5~' kill-word
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# Troca o tema do Alacritty: atheme (lista) | atheme <nome> (aplica)
atheme() {
  local win="$(wslpath "$(cd /mnt/c && cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r')")/alacritty"
  if [[ -z "$1" ]]; then
    command ls "$win/themes/themes" | sed 's/\.toml$//' | column
    return
  fi
  [[ -f "$win/themes/themes/$1.toml" ]] || { echo "Tema '$1' não existe. Rode 'atheme' para listar."; return 1; }
  sed -i "s|themes/themes/[^\"]*\.toml|themes/themes/$1.toml|" \
    ~/dotfiles/alacritty/alacritty.toml "$win/alacritty.toml"
  echo "Tema aplicado: $1"
}
