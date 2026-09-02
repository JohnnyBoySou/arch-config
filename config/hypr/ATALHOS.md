# Atalhos — Hyprland estilo macOS

`SUPER` = tecla Windows, a fazer de **Cmd**.

## Apps
| Atalho | Ação |
|---|---|
| `SUPER + Espaço` | Vicinae — launcher estilo Raycast/Spotlight (apps, arquivos, calculadora, clipboard, emojis, extensões) |
| `SUPER + R` | Spotlight antigo (wofi) — fallback |
| `SUPER` (sozinho) | Launchpad (grade de apps) |
| `SUPER + Enter` / `SUPER + T` | Terminal (ghostty) |
| `SUPER + E` | Arquivos (Dolphin) |
| `SUPER + B` | Navegador |
| `SUPER + SHIFT + V` | Histórico da área de transferência |

## Janelas
| Atalho | Ação |
|---|---|
| `SUPER + Q` / `SUPER + W` | Fechar janela |
| `SUPER + H` | Esconder (minimizar) |
| `SUPER + SHIFT + H` | Ver janelas escondidas |
| `SUPER + F` | Tela cheia |
| `SUPER + CTRL + F` | Maximizar |
| `SUPER + V` | Flutuante |
| `ALT + TAB` / `SUPER + TAB` | Alternar janela |
| `SUPER + setas` | Mover o foco |
| `SUPER + SHIFT + setas` | Mover a janela |
| `SUPER + CTRL + setas` | Redimensionar |
| `SUPER + arrastar` | Mover (botão esq.) / redimensionar (botão dir.) |

## Espaços de trabalho
| Atalho | Ação |
|---|---|
| `SUPER + 1..0` | Ir para o espaço |
| `SUPER + SHIFT + 1..0` | Mandar a janela para o espaço |
| `SUPER + CTRL + SHIFT + ←/→` | Espaço anterior / seguinte |
| `SUPER + scroll` | Trocar de espaço |
| 3 dedos no touchpad | Trocar de espaço |
| Clique no nome do workspace na menubar | Editar nome e cor da borda |
| Clique no relógio da menubar | Calendário navegável |
| Clique no calendário dos widgets | Mesmo calendário, em painel grande |
| Clique no volume da menubar | Central de som (saída, microfone, por app) |
| Clique no card de recursos dos widgets | Painel de energia (perfil, temperaturas, brilho) |
| Clique no bloco Rede do Centro de Controle | Detalhes da conexão e tráfego ao vivo |
| Clique no sino da menubar | Central de notificações (`SUPER + N`) |
| Clique direito no sino | Liga/desliga Não Perturbe |
| `SUPER + S` | Scratchpad |

## Sistema
| Atalho | Ação |
|---|---|
| `SUPER + D` | Mostrar/esconder a dock |
| Botão direito num app da dock | Menu: Fixar/Desafixar, Fechar, Fechar todas, Tela cheia, mover para workspace |
| Botão do meio num app da dock | Fechar a janela |
| `SUPER + L` / `SUPER + CTRL + Q` | Bloquear |
| `SUPER + X` | Menu de energia (também no  da menubar) |
| `SUPER + SHIFT + M` | Sair da sessão |
| `SUPER + SHIFT + 3` | Print da tela inteira (salva em ~/Pictures + área de transferência) |
| `SUPER + SHIFT + 4` | Print de uma área |
| `SUPER + SHIFT + 5` | Print da janela ativa |
| `SUPER + SHIFT + 6` | Gravar uma área (mesmo atalho para parar) |
| `SUPER + SHIFT + 7` | Gravar a tela inteira (mesmo atalho para parar) |
| `SUPER + SHIFT + ALT + 6` | Gravar uma área **com áudio** |

## Comandos úteis
| Comando | O que faz |
|---|---|
| `mac-reload` | Recarrega o Hyprland e as duas barras |
| `mac-setup` | (Re)instala o pacote visual macOS |
| `dock-toggle` | Mostra/esconde só a dock |
| `workspace-style list` | Lista nomes e cores dos workspaces |
| `workspace-style set 2 "Trabalho" "#BF5AF2"` | Muda o nome e a cor do workspace 2 |
| `nwg-look` | Trocar tema GTK / ícones / cursor pela interface |

## Arquivos
- `~/.config/hypr/hyprland.conf` — janelas, atalhos, animações
- `~/.config/hypr/workspaces.json` — nomes e cores dos workspaces
- `~/.config/waybar/config.jsonc` — menubar (topo)
- `~/.config/nwg-dock-hyprland/style.css` — visual da dock (embaixo)
- `~/.cache/nwg-dock-pinned` — apps fixados na dock (uma linha por `*.desktop`)
- `~/.config/waybar/style.css` — visual da menubar
- `~/.config/hypr/hyprpaper.conf` — papel de parede
