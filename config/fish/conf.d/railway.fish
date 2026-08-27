# O instalador do Railway so escreve em ~/.bash_profile, que o fish nunca le.
# Carrega o env.fish oficial para que atualizacoes da CLI sejam respeitadas.
if test -f $HOME/.railway/env.fish
    source $HOME/.railway/env.fish
end
