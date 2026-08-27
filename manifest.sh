#!/usr/bin/env bash
# Lista unica do que e versionado. Usada por sync.sh e install.sh.

# Itens dentro de ~/.config
CONFIG_ITEMS=(
    # Hyprland e companhia
    hypr
    waybar
    quickshell/controlcenter
    nwg-dock-hyprland
    nwg-drawer
    wofi
    swaync
    swayosd
    vicinae

    # Terminais e shell
    fish
    ghostty
    kitty
    starship.toml

    # Aparencia GTK/Qt/KDE
    gtk-3.0
    gtk-4.0
    qt5ct
    qt6ct
    Kvantum
    kdeglobals
    dolphinrc
    gwenviewrc
    trashrc

    # Apps
    mpv
    zed
    spotify-player

    # Associacoes de arquivo e pastas do usuario
    mimeapps.list
    user-dirs.dirs
)

# Units de usuario proprias (o resto de systemd/user sao symlinks gerados pelo systemctl)
SYSTEMD_UNITS=(
    wallpaper-random.service
    wallpaper-random.timer
)

# Itens dentro de ~/.local/share
SHARE_ITEMS=(
    applications/claude-code-url-handler.desktop
    color-schemes/macOSDark.colors
)

# Dotfiles soltos no ~
HOME_ITEMS=(
    .bashrc
    .bash_profile
)

# Scripts de ~/.local/bin que NAO vao pro repo
BIN_SKIP=(
    claude          # binario do Claude Code
    nwg-dock-hyprland
)
