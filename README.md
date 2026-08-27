# arch-config

Configuração do meu Arch Linux com **Hyprland** num visual estilo macOS — Waybar no topo,
dock embaixo, Launchpad, control center, Spotlight, atalhos com `SUPER` fazendo de `Cmd`.

Este repositório carrega os arquivos de config, os scripts auxiliares e a lista de pacotes,
para reproduzir o mesmo ambiente em outra máquina.

## Instalar em outra máquina

```bash
git clone https://github.com/JohnnyBoySou/arch-config.git ~/Projetos/arch-config
cd ~/Projetos/arch-config

./install.sh --dry-run      # confere o que vai ser feito, sem tocar em nada
./install.sh --packages     # instala pacotes + configs
```

Depois:

```bash
systemctl --user daemon-reload
systemctl --user enable --now wallpaper-random.timer
~/.local/bin/wallpaper-fetch     # baixa um wallpaper para ~/.cache/wallpaper
hyprctl reload                   # ou reinicie a sessão
```

O `install.sh` move tudo que já existia para `~/.config-backup-<data>` antes de escrever,
e troca `/home/sousa` por `$HOME` nos arquivos instalados (vários configs do Hyprland usam
caminho absoluto porque não expandem `~`).

Sem `--packages` ele só instala as configs. Instale os pacotes antes, à mão:

```bash
sudo pacman -S --needed - < packages/pacman.txt
yay -S --needed $(cat packages/aur.txt)
```

Os pacotes de kernel/boot/driver listados em `packages/ignore-on-install.txt` são pulados
pelo `--packages` — a outra máquina já tem os dela.

## Atualizar o repositório

Depois de mexer em qualquer config na máquina:

```bash
./sync.sh          # copia ~/.config, ~/.local/bin etc. para cá e regenera a lista de pacotes
git add -A && git commit -m "..." && git push
```

O que é versionado está em `manifest.sh` — é a lista única usada pelos dois scripts.
Para incluir uma config nova, adicione o caminho lá e rode `./sync.sh`.

## O que tem aqui

| Caminho | Conteúdo |
|---|---|
| `config/hypr/` | Hyprland, hyprlock, hypridle, hyprpaper, hyprbars + [`ATALHOS.md`](config/hypr/ATALHOS.md) |
| `config/waybar/` | barra do topo (estilo macOS, ilhas) |
| `config/quickshell/controlcenter/` | control center em QML |
| `config/nwg-dock-hyprland/`, `config/nwg-drawer/` | dock e Launchpad |
| `config/wofi/` | Spotlight, power menu |
| `config/swaync/`, `config/swayosd/` | centro de notificações e OSD de volume |
| `config/fish/` | shell (fish + starship + fisher/nvm/fzf) |
| `config/ghostty/`, `config/kitty/` | terminais |
| `config/gtk-*`, `config/qt*ct/`, `config/Kvantum/`, `config/kdeglobals` | tema WhiteSur em GTK/Qt/KDE |
| `config/dolphinrc`, `config/gwenviewrc`, `config/trashrc` | Dolphin fazendo de Finder |
| `local/bin/` | scripts: `spotlight`, `app-launcher`, `finder`, `screenshot`, `screenrecord`, `win-minimize`, `mac-clock`, `power-menu`, `wallpaper-*`… |
| `local/share/` | tema de cores macOSDark, handler de URL |
| `packages/` | `pacman.txt` (oficiais), `aur.txt` (AUR) |

## Dependências principais

Hyprland · waybar · quickshell · nwg-dock-hyprland · nwg-drawer · wofi · vicinae · swaync ·
swayosd · ghostty · fish · starship · dolphin · hyprpaper/hyprlock/hypridle · grim + slurp ·
wf-recorder · cliphist · wl-clipboard

Temas do AUR: `whitesur-gtk-theme`, `whitesur-icon-theme`, `kvantum-theme-whitesur-git`,
`apple_cursor`, `otf-san-francisco`.

## Notas

- Wallpapers não estão no repositório (são pesados). Use `~/.local/bin/wallpaper-fetch`.
- `~/.face` (foto do usuário no hyprlock/SDDM) **não** está aqui, por ser um repositório público — copie a sua para `~/.face`.
- Plugins do fish: rode `fisher update` depois de instalar (o `fish_plugins` está versionado, o `fish_variables` não).
- O `sync.sh` ignora backups (`*.bak*`, `*.pre-*`, `*.backup*`) e o histórico do fish.
