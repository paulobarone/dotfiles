#!/usr/bin/env bash
# =============================================================================
# install.sh — dotfiles para WSL + Alacritty nativo do Windows
# Distros suportadas: Arch, Ubuntu/Debian, Fedora
#
# Uso:
#   git clone https://github.com/<usuario>/dotfiles.git ~/dotfiles
#   cd ~/dotfiles && ./install.sh
#
# O script faz todas as perguntas no início e depois roda sozinho.
# =============================================================================
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"

# Respostas do usuário (preenchidas em ask_questions)
DISTRO=""        # arch | debian | fedora
GIT_NAME=""
GIT_EMAIL=""
DOCKER_MODE=""   # desktop | native | none

# ---------- Helpers ----------------------------------------------------------
info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[ERRO]\033[0m %s\n' "$*" >&2; exit 1; }

is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

# Executa comando do Windows a partir de /mnt/c (evita aviso de caminho UNC)
win_cmd() { (cd /mnt/c && cmd.exe /c "$@" 2>/dev/null | tr -d '\r'); }

# Pergunta com valor padrão: ask "Pergunta" "padrão"
ask() {
  local prompt="$1" default="${2:-}" answer
  if [[ -n "$default" ]]; then
    read -rp "  $prompt [$default]: " answer
  else
    read -rp "  $prompt: " answer
  fi
  echo "${answer:-$default}"
}

# Pergunta obrigatória (repete até ter resposta)
ask_required() {
  local value=""
  while [[ -z "$value" ]]; do
    value="$(ask "$1" "${2:-}")"
    [[ -z "$value" ]] && echo "  Campo obrigatório." >&2
  done
  echo "$value"
}

# Menu numerado: choose "Pergunta" padrão "op1" "op2" ... -> imprime o número
choose() {
  local prompt="$1" default="$2"; shift 2
  local i=1 opt answer
  echo "  $prompt" >&2
  for opt in "$@"; do echo "    $i) $opt" >&2; i=$((i + 1)); done
  while true; do
    read -rp "  Escolha [$default]: " answer
    answer="${answer:-$default}"
    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= $# )); then
      echo "$answer"; return
    fi
    echo "  Opção inválida." >&2
  done
}

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
  git clone --depth 1 -q "$url" "$dst" && ok "Clonado: $dst"
}

# Instala pacotes com o gerenciador da distro escolhida
pkg_install() {
  case "$DISTRO" in
    arch)   sudo pacman -S --needed --noconfirm "$@" ;;
    debian) sudo apt-get install -y "$@" ;;
    fedora) sudo dnf install -y "$@" ;;
  esac
}

# ---------- Pré-checagens ----------------------------------------------------
preflight() {
  [[ $EUID -ne 0 ]] || die "Não rode como root. Use seu usuário (o script chama sudo quando precisa)."
  is_wsl || die "Este script é para Linux no WSL."
  command -v sudo >/dev/null || die "sudo não encontrado. Instale o sudo e configure seu usuário antes."
}

detect_distro() {
  local ids
  ids="$( . /etc/os-release 2>/dev/null; echo "${ID:-} ${ID_LIKE:-}" )"
  case "$ids" in
    *arch*)                   echo 1 ;;
    *debian*|*ubuntu*)        echo 2 ;;
    *fedora*|*rhel*|*centos*) echo 3 ;;
    *)                        echo 1 ;;
  esac
}

# ---------- Perguntas --------------------------------------------------------
ask_questions() {
  echo
  printf '\033[1m== Configuração inicial ==\033[0m\n\n'

  # Distro
  local n
  n="$(choose "Qual distro você está usando?" "$(detect_distro)" \
       "Arch Linux (pacman)" "Ubuntu / Debian (apt)" "Fedora (dnf)")"
  case "$n" in
    1) DISTRO=arch;   command -v pacman  >/dev/null || die "pacman não encontrado nesta distro." ;;
    2) DISTRO=debian; command -v apt-get >/dev/null || die "apt não encontrado nesta distro." ;;
    3) DISTRO=fedora; command -v dnf     >/dev/null || die "dnf não encontrado nesta distro." ;;
  esac
  echo

  # Git (usa os valores atuais como padrão, se existirem)
  local cur_name="" cur_email=""
  if command -v git >/dev/null; then
    cur_name="$(git config --global user.name 2>/dev/null || true)"
    cur_email="$(git config --global user.email 2>/dev/null || true)"
  fi
  echo "  Git:"
  GIT_NAME="$(ask_required "Nome para commits" "$cur_name")"
  GIT_EMAIL="$(ask_required "E-mail para commits" "$cur_email")"
  echo

  # Docker
  local docker_default=2
  [[ -d "/mnt/c/Program Files/Docker" ]] && docker_default=1
  n="$(choose "Como você usa o Docker?" "$docker_default" \
       "Docker Desktop no Windows (não instalar no WSL)" \
       "Docker nativo dentro do WSL" \
       "Não uso Docker")"
  case "$n" in
    1) DOCKER_MODE=desktop ;;
    2) DOCKER_MODE=native ;;
    3) DOCKER_MODE=none ;;
  esac

  # Resumo
  echo
  printf '\033[1m== Resumo ==\033[0m\n'
  echo "  Distro:  $DISTRO"
  echo "  Git:     $GIT_NAME <$GIT_EMAIL>"
  echo "  Docker:  $DOCKER_MODE"
  echo
  local confirm
  read -rp "  Continuar? [S/n]: " confirm
  [[ "${confirm:-S}" =~ ^[SsYy]$ ]] || die "Cancelado."
  echo
}

# ---------- 1. Pacotes -------------------------------------------------------
install_eza_binary() {
  info "Instalando eza (binário oficial)..."
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/eza-community/eza/releases/latest/download/eza_$(uname -m)-unknown-linux-gnu.tar.gz" \
    | tar -xz -C "$tmp"
  sudo install -m 755 "$tmp/eza" /usr/local/bin/eza
  rm -rf "$tmp"
}

install_packages() {
  info "Instalando pacotes ($DISTRO)..."
  case "$DISTRO" in
    arch)
      local pkgs=(git curl unzip zsh tmux starship eza micro bat nodejs npm)
      # yarn e pnpm só se ainda não existirem (podem ter vindo do npm, o que
      # gera conflito de arquivos com o pacman)
      command -v pnpm >/dev/null || pkgs+=(pnpm)
      command -v yarn >/dev/null || pkgs+=(yarn)
      sudo pacman -Syu --needed --noconfirm "${pkgs[@]}" ;;
    debian)
      sudo apt-get update
      sudo apt-get install -y git curl unzip zsh tmux micro bat
      sudo apt-get install -y eza 2>/dev/null || true ;;
    fedora)
      sudo dnf install -y git curl unzip zsh tmux micro bat
      sudo dnf install -y eza 2>/dev/null || true ;;
  esac

  # Fallbacks para o que não existe no repositório da distro
  if ! command -v starship >/dev/null; then
    info "Instalando starship (script oficial)..."
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y >/dev/null
  fi
  command -v eza >/dev/null || install_eza_binary

  # No Ubuntu/Debian o bat se chama "batcat"; cria o atalho "bat"
  if ! command -v bat >/dev/null && command -v batcat >/dev/null; then
    sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
  fi
  ok "Pacotes instalados"
}

# ---------- 2. Git -----------------------------------------------------------
setup_git() {
  info "Configurando git..."

  # Versões antigas do script linkavam ~/.gitconfig para o repo.
  # A identidade não deve ir para o repo, então vira um arquivo local.
  if [[ -L "$HOME/.gitconfig" ]]; then
    rm "$HOME/.gitconfig"
    warn "$HOME/.gitconfig era um link para o repo; agora é um arquivo local."
  fi

  git config --global user.name  "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
  git config --global init.defaultBranch main
  git config --global --get pull.rebase >/dev/null || git config --global pull.rebase false

  # Configs compartilhadas do repo (aliases etc.), sem identidade
  if [[ -f "$DOTFILES/.gitconfig" ]]; then
    if ! { git config --global --get-all include.path || true; } | grep -qxF "$DOTFILES/.gitconfig"; then
      git config --global --add include.path "$DOTFILES/.gitconfig"
    fi
  fi
  ok "Git: $GIT_NAME <$GIT_EMAIL>"
}

# ---------- 3. Zsh -----------------------------------------------------------
setup_zsh() {
  info "Configurando zsh + Oh My Zsh..."
  if [[ ! -d "$ZSH_DIR" ]]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
  clone https://github.com/zsh-users/zsh-autosuggestions     "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

  link "$DOTFILES/.zshrc"        "$HOME/.zshrc"
  link "$DOTFILES/starship.toml" "$HOME/.config/starship.toml"
  link "$DOTFILES/micro/settings.json" "$HOME/.config/micro/settings.json"
  mkdir -p "$HOME/Projects"   # o .zshrc faz cd ~/Projects

  local zsh_path; zsh_path="$(command -v zsh)"
  if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$zsh_path" ]]; then
    sudo chsh -s "$zsh_path" "$USER" && ok "Shell padrão: zsh"
  fi
}

# ---------- 4. Tmux ----------------------------------------------------------
setup_tmux() {
  info "Configurando tmux..."
  link "$DOTFILES/.tmux.conf"        "$HOME/.tmux.conf"
  link "$DOTFILES/.tmux-sessions.sh" "$HOME/.tmux-sessions.sh"
  chmod +x "$DOTFILES/.tmux-sessions.sh"

  # Tmuxinator só se houver projetos no repo
  if compgen -G "$DOTFILES/tmuxinator/*.yml" >/dev/null; then
    pkg_install ruby
    gem install --user-install --no-document tmuxinator
    link "$DOTFILES/tmuxinator" "$HOME/.config/tmuxinator"
  fi
}

# ---------- 5. Homebrew, Node e CLIs (Vercel, Supabase) ----------------------
BREW="/home/linuxbrew/.linuxbrew/bin/brew"

setup_brew() {
  info "Configurando Homebrew..."
  case "$DISTRO" in
    arch)   pkg_install base-devel procps-ng file ;;
    debian) pkg_install build-essential procps file ;;
    fedora) sudo dnf install -y @development-tools procps-ng file ;;
  esac

  if [[ ! -x "$BREW" ]]; then
    sudo -v   # renova o sudo: o instalador do brew precisa dele sem pedir senha
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  # No fim do PATH: pacotes da distro continuam tendo prioridade
  export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin"
  ok "Homebrew pronto"
}

setup_dev_tools() {
  # Node, npm, yarn e pnpm: no Arch vêm do pacman; nas outras, do brew (versões atuais)
  if [[ "$DISTRO" != "arch" ]]; then
    info "Instalando Node, yarn e pnpm (brew)..."
    "$BREW" install node pnpm yarn
  fi

  # Pacotes globais do npm sem sudo
  npm config set prefix "$HOME/.npm-global"
  export PATH="$HOME/.npm-global/bin:$PATH"

  if ! command -v vercel >/dev/null; then
    info "Instalando Vercel CLI..."
    npm install -g vercel
  fi
  if ! command -v supabase >/dev/null; then
    info "Instalando Supabase CLI..."
    "$BREW" install supabase/tap/supabase
  fi
  ok "Node $(node --version), Vercel CLI e Supabase CLI prontos"
}

# ---------- 6. Fonte no Windows (MesloLGS Nerd Font Mono) ----------------------
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

# ---------- 7. Alacritty no Windows ---------------------------------------------
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

  # Temas (o config importa themes/themes/<tema>.toml)
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

# ---------- 8. Docker --------------------------------------------------------
setup_docker() {
  case "$DOCKER_MODE" in
    none)
      info "Docker: não instalado (escolha do usuário)"; return ;;
    desktop)
      info "Docker: usando o Docker Desktop."
      warn "No Docker Desktop, ative: Settings > Resources > WSL Integration > ${WSL_DISTRO_NAME:-sua distro}"
      return ;;
  esac

  info "Instalando Docker nativo..."
  if [[ "$DISTRO" == "arch" ]]; then
    pkg_install docker docker-compose docker-buildx
  elif ! command -v docker >/dev/null; then
    # Script oficial (Ubuntu/Debian/Fedora): instala docker, compose e buildx
    curl -fsSL https://get.docker.com | sudo sh
  fi
  sudo usermod -aG docker "$USER"

  if ! grep -qs "systemd=true" /etc/wsl.conf; then
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

# ---------- Dica final: tema do terminal -------------------------------------
show_theme_tip() {
  local Y=$'\033[1;33m' C=$'\033[1;36m' B=$'\033[1m' R=$'\033[0m' INV=$'\033[1;30;43m'
  local line="════════════════════════════════════════════════════════════"

  echo
  printf '%s\n' "${Y}${line}${R}"
  printf '%s\n' "${INV}             🎨  TROQUE O TEMA DO TERMINAL  🎨              ${R}"
  printf '%s\n' "${Y}${line}${R}"
  echo
  printf '  %s\n' "${B}O tema atual é o Iceberg. Para escolher outro:${R}"
  echo
  printf '  %s\n' "${Y}1.${R} Feche e abra o Alacritty"
  printf '  %s\n' "${Y}2.${R} Veja os temas disponíveis:"
  printf '       %s\n' "${C}atheme${R}"
  printf '  %s\n' "${Y}3.${R} Aplique um tema (muda na hora):"
  printf '       %s\n' "${C}atheme tokyo_night${R}"
  printf '       %s\n' "${C}atheme catppuccin_mocha${R}"
  printf '       %s\n' "${C}atheme dracula${R}"
  echo
  printf '  %s\n' "Prévias: ${C}https://github.com/alacritty/alacritty-theme${R}"
  echo
  printf '%s\n' "${Y}${line}${R}"
  echo
}

# ---------- Main -------------------------------------------------------------
main() {
  preflight
  ask_questions
  sudo -v
  install_packages
  setup_git
  setup_zsh
  setup_tmux
  setup_brew
  setup_dev_tools
  setup_font_windows
  setup_alacritty
  setup_docker
  echo
  ok "Setup concluído!"
  [[ -d "$BACKUP_DIR" ]] && info "Backups em: $BACKUP_DIR"
  info "Feche e reabra o Alacritty para aplicar fonte e config."
  show_theme_tip
}

main "$@"
