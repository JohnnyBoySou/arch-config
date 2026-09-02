# arch-config

Configuração do meu Arch Linux com **Hyprland** num visual estilo macOS — Waybar no topo,
dock embaixo, Launchpad, control center, Spotlight, atalhos com `SUPER` fazendo de `Cmd`.

Este repositório carrega os arquivos de config, os scripts auxiliares e a lista de pacotes,
para reproduzir o mesmo ambiente em outra máquina.

## Instalar num Arch recém-instalado

Logo depois de terminar a instalação do Arch, com o usuário já criado e com rede:

```bash
git clone https://github.com/JohnnyBoySou/arch-config.git ~/Projetos/arch-config
cd ~/Projetos/arch-config
./bootstrap.sh
```

O `bootstrap.sh` instala `git`/`base-devel`, compila o `yay` se não houver, e chama o
`install.sh --packages`. Use `./bootstrap.sh --no-aur` para pular os pacotes do AUR
(sem eles o tema WhiteSur, o cursor Apple e a fonte San Francisco não aparecem).

### A partir do pendrive (sem rede)

O pendrive Ventoy com o ISO do Arch também carrega uma cópia deste repositório em
`arch-config/`. Depois do primeiro boot no sistema novo:

```bash
sudo mount /dev/sdb1 /mnt              # a partição exFAT do Ventoy (confira com lsblk)
git clone /mnt/arch-config ~/Projetos/arch-config
cd ~/Projetos/arch-config && ./bootstrap.sh
```

Clone em vez de copiar: o exFAT não guarda a permissão de execução, e o `git clone`
devolve o bit `+x` dos scripts. Sem `git` instalado ainda:
`cp -r /mnt/arch-config ~/Projetos/ && chmod +x ~/Projetos/arch-config/*.sh`.
Os pacotes ainda exigem rede — só as configs funcionam totalmente offline
(`./install.sh` sem `--packages`).

## Instalar numa máquina que já está montada

```bash
./install.sh --dry-run      # confere o que vai ser feito, sem tocar em nada
./install.sh --packages     # instala pacotes + configs
```

Depois:

```bash
systemctl --user daemon-reload
systemctl --user enable --now wallpaper-random.timer
~/.local/bin/wallpaper-fetch     # baixa wallpapers para ~/Pictures/Wallpapers/anime
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
| `config/hypr/` | Hyprland, hyprlock, hypridle, hyprbars + [`ATALHOS.md`](config/hypr/ATALHOS.md) |
| `config/waybar/` | barra do topo (estilo macOS, ilhas) |
| `config/quickshell/controlcenter/` | control center em QML: áudio, microfone, troca de saída, DND, modo jogo, mídia e ações rápidas |
| `config/nwg-dock-hyprland/`, `config/nwg-drawer/` | dock e Launchpad |
| `config/wofi/` | Spotlight, power menu |
| `config/swaync/`, `config/swayosd/` | centro de notificações e OSD de volume |
| `config/fish/` | shell (fish + starship + fisher/nvm/fzf) |
| `config/ghostty/`, `config/kitty/` | terminais |
| `config/gtk-*`, `config/qt*ct/`, `config/Kvantum/`, `config/kdeglobals` | tema WhiteSur em GTK/Qt/KDE |
| `config/dolphinrc`, `config/gwenviewrc`, `config/trashrc` | Dolphin fazendo de Finder |
| `local/bin/` | scripts: `spotlight`, `app-launcher`, `finder`, `screenshot`, `screenrecord`, `win-minimize`, `mac-clock`, `power-menu`, `monitor-layout`, `wallpaper-*`… |
| `local/share/` | tema de cores macOSDark, handler de URL |
| `packages/` | `pacman.txt` (oficiais), `aur.txt` (AUR) |

## Dependências principais

Hyprland · waybar · quickshell · nwg-dock-hyprland · nwg-drawer · wofi · vicinae · swaync ·
swayosd · ghostty · fish · starship · dolphin · awww · hyprlock/hypridle · grim + slurp ·
wf-recorder · cliphist · wl-clipboard

Temas do AUR: `whitesur-gtk-theme`, `whitesur-icon-theme`, `kvantum-theme-whitesur-git`,
`apple_cursor`, `otf-san-francisco`.

## Notas

- Wallpapers não estão no repositório (são pesados). Use `~/.local/bin/wallpaper-fetch`.
- Cada workspace tem seu próprio wallpaper, aplicado pelo daemon `wallpaper-workspace`
  (backend `awww`, com fade linear). `wallpaper-workspace status` mostra o mapa atual;
  `Super+Shift+W` sorteia de novo o workspace ativo. No Centro de Controle, o bloco de
  wallpaper abre uma galeria para buscar, baixar, sortear ou aplicar uma imagem no
  workspace atual; as miniaturas leves ficam em `~/.cache/wallpaper/thumbs`.
- Os workspaces 1–5 têm nome e cor próprios em `~/.config/hypr/workspaces.json`.
  O nome aparece como badge ao lado do app ativo na Waybar, e a cor identifica as
  bordas das janelas daquele workspace. Clique no badge para abrir o editor visual
  de nome e cor; em `Ajustes avançados` também é possível personalizar grossura
  da borda, arredondamento, espaçamentos e animação. Para alterar pelo terminal, use
  `workspace-style set 2 "Trabalho" "#BF5AF2"`; `workspace-style list` mostra a
  configuração e `workspace-style edit` abre tudo no editor e aplica ao salvar.
- O layout dos monitores fica em `~/.config/hypr/monitors.json` e vira o
  `monitor-layout.conf` que o `hyprland.conf` carrega. O bloco **Monitores** do Centro de
  Controle (ou o ícone 󰍹 na menubar) abre um mapa onde se arrasta cada tela para posicionar,
  com encaixe nas bordas das vizinhas. Resolução, taxa, escala, rotação, espelho e
  ligar/desligar pedem confirmação de 15 s: se ela estourar, um `hyprctl reload` devolve o
  último estado salvo — é a saída para quando a mudança deixa a tela preta. Só são
  oferecidas as escalas que dão pixel inteiro naquela largura.
  Pelo terminal: `monitor-layout list`, `monitor-layout set HDMI-A-1 --x 1366`,
  `monitor-layout commit` e `monitor-layout revert`.
- O **monitor principal** (`monitor-layout primary HDMI-A-1`) é onde o workspace 1 nasce e
  onde a sessão começa focada, e é para ele que a dock migra. O interruptor
  `Menubar só no principal` estende isso à Waybar: como o binário não tem opção de saída,
  o `waybar-start` gera uma cópia do config em `~/.cache/waybar` com a chave `output`.
  Desligado, a barra sobe em todas as telas como sempre.
- Os widgets de desktop mostram relógio/data, calendário e CPU/RAM/disco na layer
  inferior, acima do wallpaper e atrás das janelas. Alterne pelo botão `Widgets` do
  Centro de Controle ou com `Super+Shift+D`.
- A engrenagem do Centro de Controle abre os ajustes persistentes de aparência do
  Hyprland: blur, sombras, animações, arredondamento, gaps e opacidade. Os valores
  ficam em `~/.config/hypr/appearance.conf`; `hypr-appearance reset` restaura o padrão.
- O calendário do widget de desktop é clicável: abre um painel navegável (mês a mês,
  `‹`/`›`, setas do teclado, `Hoje`) com feriados nacionais calculados offline —
  os fixos e os móveis derivados da Páscoa (Carnaval, Sexta-feira Santa, Corpus Christi).
  Também abre pelo relógio da menubar ou com `qs -c controlcenter ipc call calendar toggle`.
- O ícone de volume da menubar abre a **central de som** no lugar do `pavucontrol`:
  volume de saída e de microfone com medidor de nível ao vivo, troca de dispositivo
  e volume por aplicativo. A engrenagem do painel ainda abre o `pavucontrol` para
  os casos raros (perfis, roteamento fino).
- O ícone de rede da menubar (ou o bloco `Rede` do Centro de Controle) abre um painel com o enlace real (a máquina é
  cabeada, com systemd-networkd e sem Wi-Fi/Bluetooth): estado, velocidade negociada,
  IPv4/IPv6, gateway, DNS, MAC e tráfego ao vivo. Um enlace abaixo de 1 Gb/s é sinalizado.
- Os módulos de CPU e memória da menubar, e o card de CPU/RAM/disco dos widgets,
  abrem o painel de energia: perfil (via
  `power-profiles-daemon`, com o governor em leitura quando o daemon não está instalado),
  frequência média, temperaturas de CPU/GPU/NVMe, brilho do monitor por DDC/CI
  e bateria dos periféricos. A seção de brilho só aparece com `ddcutil` instalado
  **e** `/dev/i2c-*` presente (módulo `i2c-dev` carregado e usuário no grupo `i2c`);
  o `power-profiles-daemon` precisa de `systemctl enable` para valer após o boot,
  senão sobe só por ativação DBus. O teclado Logitech
  reporta faixa (`Normal`, `Baixa`…) e não porcentagem — o painel mostra a faixa.
- As notificações são servidas pelo próprio Quickshell, não mais pelo `swaync` — só um
  processo pode ser dono de `org.freedesktop.Notifications`, então o `exec-once = swaync`
  foi removido. Toasts no canto superior direito (crítica não some sozinha), central com
  histórico pelo sino da menubar ou `SUPER + N`, e Não Perturbe no clique direito do sino
  (urgência crítica fura o DND, como manda a spec). O módulo da barra não faz polling: o
  Quickshell manda `RTMIN+8` quando algo muda. O histórico vive em memória e se perde ao
  reiniciar a sessão. Se as notificações pararem, confira se o `swaync` não voltou a rodar
  (`pkill -x swaync`) e recarregue com `mac-reload`.
- O modal aberto pelo módulo de mídia busca letras sincronizadas no LRCLIB e guarda o
  resultado em `~/.cache/music-modal/lyrics`; faixas sem letras continuam com o layout normal.
- `~/.face` (foto do usuário no hyprlock/SDDM) **não** está aqui, por ser um repositório público — copie a sua para `~/.face`.
- Plugins do fish: rode `fisher update` depois de instalar (o `fish_plugins` está versionado, o `fish_variables` não).
- O `sync.sh` ignora backups (`*.bak*`, `*.pre-*`, `*.backup*`) e o histórico do fish.
