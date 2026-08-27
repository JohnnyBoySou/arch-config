# ============================================
# ABBREVIATIONS
# Visíveis ao expandir (espaço/enter), ficam no histórico como o comando real
# ============================================

if status is-interactive
    # ---- navegação ----
    abbr -a -- - 'cd -'
    abbr -a .. 'cd ..'
    abbr -a ... 'cd ../..'
    abbr -a .... 'cd ../../..'

    # ---- git ----
    abbr -a g    git
    abbr -a gs   'git status'
    abbr -a gss  'git status -sb'
    abbr -a ga   'git add'
    abbr -a gaa  'git add -A'
    abbr -a gc   'git commit'
    abbr -a gcm  'git commit -m'
    abbr -a gca  'git commit --amend'
    abbr -a gcan 'git commit --amend --no-edit'
    abbr -a gp   'git push'
    abbr -a gpf  'git push --force-with-lease'
    abbr -a gl   'git pull'
    abbr -a gd   'git diff'
    abbr -a gds  'git diff --staged'
    abbr -a gb   'git branch'
    abbr -a gco  'git checkout'
    abbr -a gcb  'git checkout -b'
    abbr -a glog 'git log --oneline --graph --decorate --all'
    abbr -a gst  'git stash'
    abbr -a gsp  'git stash pop'
    abbr -a gr   'git restore'
    abbr -a grs  'git restore --staged'
    abbr -a gcp  'git cherry-pick'
    abbr -a grb  'git rebase'
    abbr -a grbi 'git rebase -i'
    abbr -a grbc 'git rebase --continue'
    abbr -a lg   lazygit

    # ---- docker ----
    abbr -a d    docker
    abbr -a dc   'docker compose'
    abbr -a dps  'docker ps'
    abbr -a dpsa 'docker ps -a'
    abbr -a dimg 'docker images'
    abbr -a dexec 'docker exec -it'
    abbr -a dcu  'docker compose up -d'
    abbr -a dcd  'docker compose down'
    abbr -a dcl  'docker compose logs -f'

    # ---- bun / node ----
    abbr -a b    bun
    abbr -a bi   'bun install'
    abbr -a br   'bun run'
    abbr -a bd   'bun dev'
    abbr -a bb   'bun build'
    abbr -a bx   bunx
    abbr -a ni   'npm install'
    abbr -a nr   'npm run'
    abbr -a dev  'npm run dev'
    abbr -a build 'npm run build'
    abbr -a ntest 'npm test'

    # ---- system ----
    abbr -a c    clear
    abbr -a e    $EDITOR
    abbr -a v    nvim
    abbr -a md   'mkdir -p'
    abbr -a ports 'ss -tulanp'

    # ---- fish ----
    abbr -a fc 'nvim ~/.config/fish/config.fish'
    abbr -a fa 'nvim ~/.config/fish/conf.d/abbreviations.fish'
    abbr -a fr 'source ~/.config/fish/config.fish'

end
