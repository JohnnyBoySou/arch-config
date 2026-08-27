#!/usr/bin/env bash
# Copia as configs desta maquina para dentro do repositorio.
# Uso: ./sync.sh   (rodar sempre que mexer em alguma config e quiser versionar)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO/manifest.sh"

# Padroes de arquivo que nunca entram no repo (backups feitos durante os testes).
prune_backups() {
    find "$1" \( \
        -name '*.bak' -o -name '*.bak-*' -o -name '*.backup*' \
        -o -name '*.pre-*' -o -name '*.old' -o -name '*.nao-usado' \
        -o -name '__pycache__' -o -name '*.tbcache' \
    \) -exec rm -rf {} + 2>/dev/null || true
}

copy_into() { # copy_into <origem-absoluta> <destino-no-repo>
    local src="$1" dest="$2"
    [[ -e "$src" ]] || { echo "  (ausente, ignorado) $src"; return; }
    mkdir -p "$(dirname "$dest")"
    rm -rf "$dest"
    cp -a "$src" "$dest"
    [[ -d "$dest" ]] && prune_backups "$dest"
    echo "  ok  ${src/#$HOME/\~}"
}

echo "==> ~/.config"
for item in "${CONFIG_ITEMS[@]}"; do
    copy_into "$HOME/.config/$item" "$REPO/config/$item"
done

echo "==> ~/.config/systemd/user (units proprias)"
mkdir -p "$REPO/config/systemd/user"
for unit in "${SYSTEMD_UNITS[@]}"; do
    copy_into "$HOME/.config/systemd/user/$unit" "$REPO/config/systemd/user/$unit"
done

echo "==> ~/.local/bin"
rm -rf "$REPO/local/bin"; mkdir -p "$REPO/local/bin"
for f in "$HOME"/.local/bin/*; do
    name="$(basename "$f")"
    [[ -L "$f" ]] && continue                 # symlinks de binarios instalados
    case " ${BIN_SKIP[*]} " in *" $name "*) continue ;; esac
    copy_into "$f" "$REPO/local/bin/$name"
done
prune_backups "$REPO/local/bin"

echo "==> ~/.local/share"
for item in "${SHARE_ITEMS[@]}"; do
    copy_into "$HOME/.local/share/$item" "$REPO/local/share/$item"
done

echo "==> ~ (dotfiles soltos)"
for item in "${HOME_ITEMS[@]}"; do
    copy_into "$HOME/$item" "$REPO/home/$item"
done

echo "==> lista de pacotes"
pacman -Qqen > "$REPO/packages/pacman.txt"     # repos oficiais, instalados explicitamente
pacman -Qqem > "$REPO/packages/aur.txt"        # AUR / foreign
echo "  ok  $(wc -l < "$REPO/packages/pacman.txt") pacotes oficiais, $(wc -l < "$REPO/packages/aur.txt") do AUR"

echo
echo "Pronto. Revise com 'git -C $REPO status' e faca o commit."
