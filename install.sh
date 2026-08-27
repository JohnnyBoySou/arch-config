#!/usr/bin/env bash
# Instala estas configs na maquina atual.
#
#   ./install.sh              instala as configs (faz backup do que ja existe)
#   ./install.sh --packages   instala tambem os pacotes de packages/
#   ./install.sh --dry-run    so mostra o que seria feito
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO/manifest.sh"

ORIGINAL_HOME="/home/sousa"   # home da maquina onde as configs nasceram
BACKUP="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
WITH_PACKAGES=0

for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY_RUN=1 ;;
        --packages) WITH_PACKAGES=1 ;;
        -h|--help)  sed -n '2,7p' "$0"; exit 0 ;;
        *) echo "opcao desconhecida: $arg"; exit 1 ;;
    esac
done

run() { if (( DRY_RUN )); then echo "  [dry] $*"; else "$@"; fi; }

# Copia repo -> sistema, guardando o original em $BACKUP e corrigindo o path do home.
install_item() { # install_item <origem-no-repo> <destino-absoluto>
    local src="$1" dest="$2"
    [[ -e "$src" ]] || return 0
    if [[ -e "$dest" || -L "$dest" ]]; then
        local rel="${dest/#$HOME\//}"
        run mkdir -p "$BACKUP/$(dirname "$rel")"
        run mv "$dest" "$BACKUP/$rel"
    fi
    run mkdir -p "$(dirname "$dest")"
    run cp -a "$src" "$dest"
    echo "  ok  ${dest/#$HOME/\~}"
}

# Troca /home/sousa por $HOME nos arquivos de texto instalados (varios configs
# do Hyprland usam caminho absoluto porque nao expandem ~).
fix_paths() {
    [[ "$HOME" == "$ORIGINAL_HOME" ]] && return 0
    (( DRY_RUN )) && { echo "  [dry] sed $ORIGINAL_HOME -> $HOME"; return 0; }
    local target count=0
    for target in "$@"; do
        [[ -e "$target" ]] || continue
        while IFS= read -r -d '' f; do
            grep -Iq . "$f" 2>/dev/null || continue          # pula binarios
            if grep -q "$ORIGINAL_HOME" "$f"; then
                sed -i "s|$ORIGINAL_HOME|$HOME|g" "$f"
                count=$((count + 1))
            fi
        done < <(find "$target" -type f -print0)
    done
    echo "  ok  caminhos ajustados para $HOME ($count arquivo(s))"
}

echo "==> backup do que ja existe: $BACKUP"

echo "==> ~/.config"
for item in "${CONFIG_ITEMS[@]}"; do
    install_item "$REPO/config/$item" "$HOME/.config/$item"
done

echo "==> ~/.config/systemd/user"
for unit in "${SYSTEMD_UNITS[@]}"; do
    install_item "$REPO/config/systemd/user/$unit" "$HOME/.config/systemd/user/$unit"
done

echo "==> ~/.local/bin"
for f in "$REPO"/local/bin/*; do
    [[ -e "$f" ]] || continue
    install_item "$f" "$HOME/.local/bin/$(basename "$f")"
done
(( DRY_RUN )) || chmod +x "$HOME"/.local/bin/* 2>/dev/null || true

echo "==> ~/.local/share"
for item in "${SHARE_ITEMS[@]}"; do
    install_item "$REPO/local/share/$item" "$HOME/.local/share/$item"
done

echo "==> ~"
for item in "${HOME_ITEMS[@]}"; do
    install_item "$REPO/home/$item" "$HOME/$item"
done

echo "==> ajuste de caminhos"
fix_paths "$HOME/.config/hypr" "$HOME/.config/waybar" "$HOME/.config/wofi" \
          "$HOME/.config/swaync" "$HOME/.config/quickshell" "$HOME/.local/bin" \
          "$HOME/.config/systemd/user" "$HOME/.local/share/applications"

if (( WITH_PACKAGES )); then
    echo "==> pacotes oficiais (pacman)"
    ignore="$(grep -vE '^\s*(#|$)' "$REPO/packages/ignore-on-install.txt")"
    pkgs="$(grep -vxF "$ignore" "$REPO/packages/pacman.txt" | tr '\n' ' ')"
    echo "  $(wc -w <<< "$pkgs") pacotes (pulando os de kernel/driver desta maquina)"
    run sudo pacman -S --needed --noconfirm $pkgs
    echo "==> pacotes do AUR (yay)"
    if command -v yay >/dev/null; then
        run yay -S --needed --noconfirm $(grep -vE '^(yay|.*-debug)$' "$REPO/packages/aur.txt" | tr '\n' ' ')
    else
        echo "  yay nao encontrado. Instale primeiro:"
        echo "    sudo pacman -S --needed git base-devel"
        echo "    git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si"
    fi
fi

echo
echo "Feito. Backup do estado anterior em: $BACKUP"
cat <<'FIM'

Passos finais:
  systemctl --user daemon-reload
  systemctl --user enable --now wallpaper-random.timer
  ~/.local/bin/wallpaper-fetch          # baixa um wallpaper para ~/.cache/wallpaper
  hyprctl reload                        # ou reinicie a sessao do Hyprland
FIM
