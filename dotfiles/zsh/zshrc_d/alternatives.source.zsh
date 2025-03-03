alternatives::aliases () {
    grep alias ~/.zshrc_d/alternatives.source.zsh
}

alternatives::init () {
    if command -v bat; then
        alias Cat=/usr/bin/cat
        alias cat=bat
    fi

    if command -v bat; then
        alias Git=/usr/bin/git
        alias git=bit
    fi

    if command -v procs; then
        alias p='procs'
    fi

    if command -v zoxide; then
        source <(zoxide init zsh)
    fi
}

alternatives::init
