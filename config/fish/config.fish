# ============================================
# INTERACTIVE
# ============================================

if status is-interactive && type -q starship
    starship init fish | source

    function starship_transient_prompt_func
        printf '\e[1;38;2;189;147;249m❯\e[0m '
    end

    enable_transience
end

if status is-interactive
    fish_user_key_bindings
end

# ============================================
# PATHS
# ============================================

# fish_add_path evita duplicatas quando o arquivo e recarregado com `source`.
fish_add_path -g $HOME/.local/bin

# Bun
set -gx BUN_INSTALL $HOME/.bun
fish_add_path -g $BUN_INSTALL/bin

# Node: usa o nvm.fish instalado pelo Fisher, sem misturar com o NVM de Bash.
# A familia 24 acompanha automaticamente a versao 24.x mais recente instalada.
if status is-interactive && type -q nvm && not set -q nvm_current_version
    nvm use --silent 24
end

# ============================================
# SHELL SETTINGS
# ============================================

set -g fish_greeting ""

# As cores ficam centralizadas em conf.d/colors.fish.

# ============================================
# TOOLS
# ============================================

# zoxide (cd inteligente)
if type -q zoxide
    zoxide init fish | source
end

# fzf — bindings nativos do fzf desabilitados; fzf.fish (PatrickF1) cobre Ctrl+R, Ctrl+Alt+F, etc.
if type -q fd
    set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git --exclude node_modules'
    set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
    set -gx FZF_ALT_C_COMMAND  'fd --type d --hidden --follow --exclude .git --exclude node_modules'
    set -g  fzf_fd_opts        --hidden --follow --exclude=.git --exclude=node_modules
end

if type -q bat
    set -g fzf_preview_file_cmd 'bat --style=numbers --color=always --line-range :500'
end

if type -q delta
    set -g fzf_diff_highlighter 'delta --paging=never --width=20'
end

set -gx FZF_DEFAULT_OPTS '--height=60% --layout=reverse --border=rounded --margin=1 --padding=0,1 --info=inline --prompt="❯ " --pointer="▶" --marker="◆" --color=border:#6272a4,prompt:#bd93f9,pointer:#ff79c6,marker:#50fa7b'

# ============================================
# ALIASES — apenas rebindings (ls→eza, rm -i, etc.)
# Atalhos curtos vivem em conf.d/abbreviations.fish
# ============================================

# LS moderno
if type -q eza
    alias ls "eza --icons"
    alias ll "eza -lah --icons --git"
    alias la "eza -a --icons"
    alias l "eza --icons"
    alias tree "eza --tree --icons"
else
    alias ll "ls -lah"
    alias la "ls -A"
    alias l "ls -CF"
end

# CAT moderno
if type -q bat
    alias cat "bat --paging=never"
end

# system
alias df "df -h"
alias du "du -h"
alias free "free -h"
alias top "htop 2>/dev/null || top"

# search com cor
alias grep "grep --color=auto"
alias fgrep "fgrep --color=auto"
alias egrep "egrep --color=auto"

# safety
alias rm "rm -i"
alias cp "cp -i"
alias mv "mv -i"

# format / lint
alias format "npm run format 2>/dev/null || biome format --write . 2>/dev/null || prettier --write ."
alias lint-fix "npm run lint:fix 2>/dev/null || biome lint --write . 2>/dev/null || eslint --fix ."

# ============================================
# EDITOR
# ============================================

if type -q nvim
    set -gx EDITOR nvim
else if type -q vim
    set -gx EDITOR vim
else
    set -gx EDITOR nano
end
set -gx VISUAL $EDITOR

# Alguns launchers graficos entregam um PATH ja duplicado. Preserva a ordem e
# remove repeticoes para nao degradar a busca de comandos ao longo da sessao.
function __dedupe_path
    set -l clean_path
    for directory in $PATH
        contains -- $directory $clean_path || set -a clean_path $directory
    end
    set -gx PATH $clean_path
end
__dedupe_path
functions --erase __dedupe_path
