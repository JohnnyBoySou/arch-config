#!/usr/bin/env fish

# Renderiza o diretorio atual como segmentos Powerline em true color.
set -l logical_pwd (pwd -L)
set -l parts

if test "$logical_pwd" = "$HOME"
    set parts '~'
else if string match -q -- "$HOME/*" "$logical_pwd"
    set parts '~' (string split / (string replace -- "$HOME/" '' "$logical_pwd"))
else if test "$logical_pwd" = /
    set parts /
else
    set parts / (string split / (string trim --left --chars=/ "$logical_pwd"))
end

# Evita que caminhos muito profundos dominem toda a linha do prompt.
if test (count $parts) -gt 6
    set parts $parts[1] '…' $parts[-4..-1]
end

# O ultimo segmento indica rapidamente o contexto atual.
set -l context_icon '󰉋'
if test "$logical_pwd" = "$HOME"
    set context_icon '󰋜'
else if command git -C "$logical_pwd" rev-parse --is-inside-work-tree >/dev/null 2>&1
    set context_icon '󰊢'
end
set parts[-1] "$context_icon $parts[-1]"

set -l segment_count (count $parts)
set -l denominator (math "max(1, $segment_count - 1)")

# Inicio azul-acinzentado; fim roxo vivo.
set -l start_rgb 59 66 97
set -l end_rgb 189 147 249
set -l previous_rgb

for index in (seq $segment_count)
    set -l step
    if test $segment_count -eq 1
        set step $denominator
    else
        set step (math "$index - 1")
    end

    set -l red (math --scale=0 "$start_rgb[1] + ($end_rgb[1] - $start_rgb[1]) * $step / $denominator")
    set -l green (math --scale=0 "$start_rgb[2] + ($end_rgb[2] - $start_rgb[2]) * $step / $denominator")
    set -l blue (math --scale=0 "$start_rgb[3] + ($end_rgb[3] - $start_rgb[3]) * $step / $denominator")
    set -l current_rgb $red $green $blue

    if test $index -gt 1
        printf '\e[38;2;%d;%d;%d;48;2;%d;%d;%dm' \
            $previous_rgb[1] $previous_rgb[2] $previous_rgb[3] \
            $current_rgb[1] $current_rgb[2] $current_rgb[3]
    end

    printf '\e[1;38;2;248;248;242;48;2;%d;%d;%dm %s ' \
        $current_rgb[1] $current_rgb[2] $current_rgb[3] $parts[$index]
    set previous_rgb $current_rgb
end

printf '\e[0;38;2;%d;%d;%dm\e[0m ' \
    $previous_rgb[1] $previous_rgb[2] $previous_rgb[3]
