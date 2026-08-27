function fish_user_key_bindings
    # fzf.fish (Fisher) registra seus proprios atalhos. Alt+E abre o comando
    # atual no $EDITOR e preserva os bindings do plugin sem inicializar fzf duas vezes.
    bind \ee edit_command_buffer
end
