# dotfiles

Configuração completa de terminal para **Windows + WSL**, instalada com um único comando.

O que vem junto:

| Ferramenta | O que faz |
|---|---|
| **Alacritty** | Terminal rápido, rodando no Windows, com tema Iceberg, transparência e fonte MesloLGS Nerd Font |
| **zsh + Oh My Zsh** | Shell com autosugestões, destaque de sintaxe e plugins para git e docker |
| **Starship** | Prompt com branch do git, linguagem do projeto e outros indicadores |
| **tmux** | Três sessões fixas (`main`, `secondary`, `third`) abertas automaticamente |
| **eza** | `ls` com ícones e status do git |
| **micro** | Editor de texto no terminal com atalhos comuns (Ctrl+S, Ctrl+C, Ctrl+V) |
| **git** | Nome e e-mail configurados durante a instalação |
| **Docker** | Opcional: nativo no WSL ou via Docker Desktop |

---

## Requisitos

- Windows 10 (versão 2004 ou superior) ou Windows 11
- WSL com uma destas distros: **Arch Linux**, **Ubuntu/Debian** ou **Fedora**
- **Alacritty** instalado no Windows

---

## Instalação

### 1. Instale o WSL e uma distro

No **PowerShell** do Windows:

```powershell
# Escolha uma:
wsl --install archlinux
wsl --install Ubuntu
```

Reinicie o computador se o Windows pedir.

### 2. Instale o Alacritty no Windows

```powershell
winget install Alacritty.Alacritty
```

### 3. Crie seu usuário (só no Arch)

O Ubuntu cria o usuário automaticamente na primeira abertura. O Arch abre como root, então crie um usuário antes (troque `seunome`):

```bash
pacman -Syu --noconfirm sudo git
useradd -m -G wheel -s /bin/bash seunome
passwd seunome
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
printf '[user]\ndefault=seunome\n' >> /etc/wsl.conf   # usuário padrão do WSL
```

No PowerShell, reinicie o WSL para aplicar:

```powershell
wsl --shutdown
```

Feche e abra o terminal do Arch de novo.

### 4. Baixe o dotfiles

Recomendado: faça um **fork** deste repositório no GitHub (botão *Fork* no topo da página). Assim você pode personalizar tudo e salvar no seu próprio repositório.

Instale o git (se ainda não tiver) e clone:

```bash
# Arch
sudo pacman -S git
# Ubuntu/Debian
sudo apt update && sudo apt install -y git

git clone https://github.com/SEU_USUARIO/dotfiles.git ~/dotfiles
```

Troque `SEU_USUARIO` pelo seu usuário do GitHub (se fez fork) ou por `paulobarone` (para usar o original).

### 5. Rode o instalador

```bash
cd ~/dotfiles
./install.sh
```

O script faz algumas perguntas no início e depois roda sozinho:

1. **Distro:** detectada automaticamente, basta confirmar com Enter.
2. **Git:** seu nome e e-mail para os commits.
3. **Docker:**
   - *Docker Desktop:* nada é instalado no WSL. Depois, ative a integração em **Docker Desktop → Settings → Resources → WSL Integration**.
   - *Docker nativo:* instala o Docker dentro do WSL.
   - *Não uso Docker:* pula essa parte.

Ele mostra um resumo e pede confirmação antes de instalar qualquer coisa.

> **Se aparecer o aviso de systemd:** rode `wsl --shutdown` no PowerShell, abra o terminal de novo e rode `./install.sh` outra vez. Isso só acontece na primeira vez, ao escolher Docker nativo.

### 6. Abra o Alacritty

Feche todas as janelas do Alacritty e abra de novo. Ele abre direto no tmux, na sessão `main`, dentro de `~/Projects`.

---

## Uso no dia a dia

### Atalhos do terminal

| Atalho | Ação |
|---|---|
| `Ctrl+Backspace` | Apaga a palavra anterior (para em `/`, `-`, `.`) |
| `Ctrl+Delete` | Apaga a próxima palavra |
| `Ctrl+←` / `Ctrl+→` | Pula uma palavra |
| `Ctrl+V` ou botão direito | Cola |
| Selecionar com o mouse | Copia automaticamente |
| `Ctrl+clique` em um link | Abre no navegador |

### Sessões do tmux

O prefixo do tmux é `Ctrl+B` (aperte, solte e depois aperte a próxima tecla).

| Atalho | Ação |
|---|---|
| `Alt+←` / `Alt+→` | Sessão anterior / próxima |
| `Ctrl+B` e `Shift+M` | Vai para `main` |
| `Ctrl+B` e `Shift+S` | Vai para `secondary` |
| `Ctrl+B` e `Shift+T` | Vai para `third` |

A barra inferior mostra as três sessões, com a atual destacada.

### Editor de texto (micro)

```bash
micro arquivo.txt
```

Os atalhos são os mesmos de qualquer editor: `Ctrl+S` salva, `Ctrl+Q` sai, `Ctrl+F` busca, `Ctrl+Z` desfaz. `Ctrl+G` mostra a ajuda completa.

Para trocar o tema do micro: `Ctrl+E` e digite `set colorscheme dracula-tc` (outros: `gruvbox-tc`, `monokai`, `material-tc`, `solarized-tc`).

### Tema do Alacritty

```bash
atheme                  # lista todos os temas disponíveis
atheme tokyo_night      # aplica um tema na hora
```

Prévias de todos os temas: [alacritty-theme](https://github.com/alacritty/alacritty-theme).

---

## Personalização

Os arquivos de configuração ficam no repositório e são ligados (*symlinks*) à sua pasta home. Então, editar o arquivo no repo já vale na hora:

| Arquivo no repo | Para que serve |
|---|---|
| `.zshrc` | Shell, aliases, plugins |
| `starship.toml` | Visual do prompt |
| `.tmux.conf` | tmux: barra, atalhos |
| `.tmux-sessions.sh` | Sessões abertas ao iniciar |
| `micro/settings.json` | Editor micro |
| `alacritty/alacritty.toml` | Terminal (copiado para `%APPDATA%\alacritty\` no Windows) |

> O config do Alacritty é **copiado** para o Windows, não linkado. Depois de editar `alacritty/alacritty.toml`, rode `./install.sh` de novo para aplicar. A exceção é o `atheme`, que já atualiza os dois lugares.

Para salvar suas mudanças no GitHub:

```bash
cd ~/dotfiles
git add -A && git commit -m "minhas mudanças" && git push
```

---

## Atualizar

Para pegar a versão mais recente do repositório:

```bash
cd ~/dotfiles
git pull
./install.sh
```

O script pode ser rodado quantas vezes quiser: o que já está instalado é pulado.

---

## Backups e como desfazer

Antes de substituir qualquer arquivo seu, o script guarda uma cópia em:

```
~/.dotfiles_backup/<data_hora>/
```

Para voltar um arquivo ao que era antes, copie de volta. Exemplo:

```bash
rm ~/.zshrc
cp ~/.dotfiles_backup/20261027_211757/.zshrc ~/.zshrc
```

O config antigo do Alacritty fica no mesmo lugar, com o nome `alacritty.toml.windows`.

---

## Problemas comuns

**A fonte aparece com quadrados ou símbolos estranhos**
Feche todas as janelas do Alacritty e abra de novo. Se continuar, confira se a fonte *MesloLGS Nerd Font Mono* aparece em **Configurações do Windows → Personalização → Fontes**.

**`docker: permission denied`**
Feche e abra o terminal (o grupo `docker` só vale numa sessão nova).

**O Alacritty abre e fecha na hora**
Confira o nome da sua distro com `wsl -l -v` no PowerShell e rode `./install.sh` de novo dentro dela.

**O terminal ficou claro demais**
Teste `opacity = 1.0` no `alacritty/alacritty.toml` ou troque de tema com `atheme`.
