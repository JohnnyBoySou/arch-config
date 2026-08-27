pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // ── Cores (mesma paleta da menubar Waybar) ──────────────
    readonly property color bg:          "#1c1c1e"
    readonly property color panel:       Qt.rgba(0.11, 0.11, 0.12, 0.72)
    readonly property color card:        Qt.rgba(1, 1, 1, 0.10)
    readonly property color cardHover:   Qt.rgba(1, 1, 1, 0.16)
    readonly property color cardActive:  "#0a84ff"

    readonly property color text:        "#f2f2f7"
    readonly property color textDim:     Qt.rgba(0.949, 0.949, 0.968, 0.55)
    readonly property color stroke:      Qt.rgba(1, 1, 1, 0.12)

    readonly property color accent:      "#0a84ff"
    readonly property color danger:      "#ff453a"
    readonly property color warning:     "#ff9f0a"
    readonly property color success:     "#30d158"

    // ── Métrica ─────────────────────────────────────────────
    readonly property int   panelWidth:  420
    readonly property int   pad:         20
    readonly property int   gap:         14
    readonly property int   radiusPanel: 24
    readonly property int   radiusCard:  16
    readonly property int   tileHeight:  80

    // ── Métrica interna dos componentes ─────────────────────
    readonly property int   cardPad:      16   // respiro dentro dos cartões
    readonly property int   badge:        38   // círculo do ícone nos ladrilhos
    readonly property int   iconSize:     17
    readonly property int   sliderHeight: 42
    readonly property int   actionHeight: 72
    readonly property int   actionBadge:  42
    readonly property int   statsHeight:  70
    readonly property int   mediaHeight:  96
    readonly property int   mediaArt:     70

    // ── Tipografia ──────────────────────────────────────────
    readonly property string fontFamily: "SF Pro Text"
    readonly property string fontFallback: "Inter"
    readonly property string iconFamily: "JetBrainsMono Nerd Font"
    readonly property int   fontSize:    14
    readonly property int   fontSizeSm:  12

    // ── Animação (curva do macOS) ───────────────────────────
    readonly property int   anim:        180
    readonly property var   easing:      [0.22, 1, 0.36, 1]
}
