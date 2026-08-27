#!/usr/bin/env bash
# Primeira execucao num Arch recem-instalado: prepara o que o install.sh precisa
# (git, base-devel, yay) e em seguida instala pacotes + configs.
#
#   ./bootstrap.sh              instala tudo
#   ./bootstrap.sh --no-aur     pula os pacotes do AUR
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WITH_AUR=1
[[ "${1:-}" == "--no-aur" ]] && WITH_AUR=0

command -v pacman >/dev/null || { echo "Isto so roda em Arch (pacman nao encontrado)."; exit 1; }
[[ $EUID -eq 0 ]] && { echo "Nao rode como root: o install.sh escreve no HOME do usuario."; exit 1; }

echo "==> base: git, base-devel"
sudo pacman -Syu --needed --noconfirm git base-devel

if (( WITH_AUR )) && ! command -v yay >/dev/null; then
    echo "==> compilando o yay (AUR)"
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

echo "==> pacotes + configs"
if (( WITH_AUR )); then
    "$REPO/install.sh" --packages
else
    "$REPO/install.sh" --packages --no-aur
fi

echo "==> servicos"
systemctl --user daemon-reload
systemctl --user enable --now wallpaper-random.timer || true
command -v sddm >/dev/null && ! systemctl is-enabled -q sddm && \
    echo "  dica: sudo systemctl enable sddm   (gerenciador de login)"

cat <<'FIM'

Tudo instalado. Falta so:
  ~/.local/bin/wallpaper-fetch      # baixa um wallpaper (ou copie o seu para ~/.cache/wallpaper/current)
  chsh -s /usr/bin/fish             # deixar o fish como shell padrao
  fisher update                     # plugins do fish (dentro de um shell fish)

Depois entre numa sessao Hyprland (pelo SDDM) ou rode 'hyprctl reload' se ja estiver nela.
FIM
