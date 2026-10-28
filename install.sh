#!/usr/bin/env bash
# =============================================================================
# install.sh — dotfiles (Arch Linux no WSL + Alacritty nativo do Windows)
#
# Uso:
#   git clone git@github.com:paulobarone/dotfiles.git ~/dotfiles
#   cd ~/dotfiles && ./install.sh [--skip-docker]
# =============================================================================
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"

PACKAGES=(
  base-devel git curl unzip
  zsh tmux starship eza
  docker docker-compose docker-buildx
)

SKIP_DOCKER=false
[[ "${1:-}" == "--skip-docker" ]] && SKIP_DOCKER=true

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }

is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

# Executa comando do Windows a partir de /mnt/c (evita aviso de caminho UNC)
win_cmd() { (cd /mnt/c && cmd.exe /c "$@" 2>/dev/null | tr -d '\r'); }

# Symlink com backup do que já existir
link() {
  local src="$1" dst="$2"
  [[ -e "$src" ]] || { warn "Não encontrado, pulando: $src"; return; }
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
    ok "Já linkado: $dst"; return
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR" && mv "$dst" "$BACKUP_DIR/"
    warn "Backup: $dst -> $BACKUP_DIR/"
  fi
  ln -s "$src" "$dst" && ok "Link: $dst"
}

# Clona repositório só se ainda não existir
clone() {
  local url="$1" dst="$2"
  [[ -d "$dst/.git" ]] && { ok "Já existe: $dst"; return; }
  git clone --depth 1 "$url" "$dst" && ok "Clonado: $dst"
}

# ---------------------------------------------------------------------------
preflight() {
  [[ $EUID -ne 0 ]] || { echo "Não rode como root."; exit 1; }
  command -v pacman >/dev/null || { echo "pacman não encontrado."; exit 1; }
  is_wsl || { echo "Este script é para Arch no WSL."; exit 1; }
  sudo -v
}

install_packages() {
  info "Instalando pacotes..."
  sudo pacman -Syu --needed --noconfirm "${PACKAGES[@]}"
}

setup_zsh() {
  info "Configurando zsh + Oh My Zsh..."
  if [[ ! -d "$ZSH_DIR" ]]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
  # Plugins de terceiros usados no .zshrc
  clone https://github.com/zsh-users/zsh-autosuggestions     "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

  link "$DOTFILES/.zshrc"         "$HOME/.zshrc"
  link "$DOTFILES/starship.toml"  "$HOME/.config/starship.toml"
  mkdir -p "$HOME/Projects"   # o .zshrc faz cd ~/Projects

  if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "/bin/zsh" ]]; then
    sudo chsh -s /bin/zsh "$USER" && ok "Shell padrão: zsh"
  fi
}

setup_tmux() {
  info "Configurando tmux..."
  link "$DOTFILES/.tmux.conf"        "$HOME/.tmux.conf"
  link "$DOTFILES/.tmux-sessions.sh" "$HOME/.tmux-sessions.sh"
  chmod +x "$DOTFILES/.tmux-sessions.sh"

  # Tmuxinator só se houver projetos no repo
  if compgen -G "$DOTFILES/tmuxinator/*.yml" >/dev/null; then
    sudo pacman -S --needed --noconfirm ruby
    gem install --user-install --no-document tmuxinator
    link "$DOTFILES/tmuxinator" "$HOME/.config/tmuxinator"
  fi
}

# ---------- Fonte no Windows (MesloLGS Nerd Font Mono) ----------------------
setup_font_windows() {
  info "Instalando MesloLGS Nerd Font no Windows..."
  local tmp_win tmp_unix
  tmp_win="$(win_cmd "echo %LOCALAPPDATA%")\\Temp\\nerdfont_meslo"
  tmp_unix="$(wslpath -u "$tmp_win")"

  rm -rf "$tmp_unix" && mkdir -p "$tmp_unix"
  curl -fsSL -o "$tmp_unix/font.zip" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip
  unzip -oq "$tmp_unix/font.zip" 'MesloLGSNerdFontMono-*' -d "$tmp_unix"
  rm "$tmp_unix/font.zip"

  # Instalação por usuário (não exige admin)
  cat > "$tmp_unix/install_fonts.ps1" <<'PS1'
param([string]$Src)
$dst = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Get-ChildItem -Path $Src -Filter *.ttf | ForEach-Object {
  $target = Join-Path $dst $_.Name
  if (Test-Path $target) { return }   # já instalada (e possivelmente em uso)
  Copy-Item $_.FullName -Destination $dst -Force
  New-ItemProperty -Path $reg -Name ($_.BaseName + ' (TrueType)') `
    -Value (Join-Path $dst $_.Name) -PropertyType String -Force | Out-Null
}
PS1
  (cd /mnt/c && powershell.exe -NoProfile -ExecutionPolicy Bypass \
    -File "${tmp_win}\\install_fonts.ps1" -Src "$tmp_win")
  rm -rf "$tmp_unix"
  ok "Fonte instalada no Windows"
}

# ---------- Alacritty no Windows ---------------------------------------------
setup_alacritty() {
  info "Configurando Alacritty (Windows)..."
  local appdata dst distro
  appdata="$(wslpath -u "$(win_cmd "echo %APPDATA%")")"
  dst="$appdata/alacritty"
  distro="${WSL_DISTRO_NAME:-archlinux}"
  mkdir -p "$dst"

  if [[ -f "$dst/alacritty.toml" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp "$dst/alacritty.toml" "$BACKUP_DIR/alacritty.toml.windows"
    warn "Backup do config atual do Windows em $BACKUP_DIR/"
  fi

  # Cópia com o nome da distro preenchido (symlink WSL -> Windows não funciona)
  sed "s/{{WSL_DISTRO}}/$distro/" "$DOTFILES/alacritty/alacritty.toml" > "$dst/alacritty.toml"
  ok "Config em %APPDATA%\\alacritty\\alacritty.toml (distro: $distro)"

  # Temas (o config importa themes/themes/nord.toml)
  local tmp; tmp="$(mktemp -d)"
  git clone --depth 1 -q https://github.com/alacritty/alacritty-theme "$tmp"
  mkdir -p "$dst/themes"
  rm -rf "$dst/themes/themes" && cp -r "$tmp/themes" "$dst/themes/themes"
  rm -rf "$tmp"
  ok "Temas copiados para o Windows"

  if [[ -z "$(win_cmd "where alacritty")" ]] && \
     [[ ! -f "/mnt/c/Program Files/Alacritty/alacritty.exe" ]]; then
    warn "Alacritty não encontrado no Windows. Instale com: winget install Alacritty.Alacritty"
  fi
}

setup_git() {
  if [[ -f "$DOTFILES/.gitconfig" ]]; then
    link "$DOTFILES/.gitconfig" "$HOME/.gitconfig"
  elif [[ -z "$(git config --global user.name || true)" ]]; then
    info "Configurando git..."
    read -rp "  Nome para commits: " name
    read -rp "  E-mail para commits: " email
    git config --global user.name  "$name"
    git config --global user.email "$email"
    git config --global init.defaultBranch main
    git config --global core.editor "code --wait"
    git config --global pull.rebase false
  fi
  ok "Git configurado"
}

setup_docker() {
  $SKIP_DOCKER && { warn "Docker pulado"; return; }
  info "Configurando docker..."
  sudo usermod -aG docker "$USER"

  if is_wsl && ! grep -qs "systemd=true" /etc/wsl.conf; then
    printf '\n[boot]\nsystemd=true\n' | sudo tee -a /etc/wsl.conf >/dev/null
    warn "systemd habilitado. Rode 'wsl --shutdown' no Windows, reabra e rode ./install.sh de novo."
    return
  fi
  if [[ "$(ps -p 1 -o comm=)" == "systemd" ]]; then
    sudo systemctl enable --now docker.service && ok "Docker rodando"
  else
    warn "systemd inativo. Reinicie o WSL e rode: sudo systemctl enable --now docker"
  fi
}

main() {
  preflight
  install_packages
  setup_git
  setup_zsh
  setup_tmux
  setup_font_windows
  setup_alacritty
  setup_docker
  echo
  ok "Setup concluído!"
  [[ -d "$BACKUP_DIR" ]] && info "Backups em: $BACKUP_DIR"
  info "Feche e reabra o Alacritty para aplicar fonte e config."
}

main "$@"
