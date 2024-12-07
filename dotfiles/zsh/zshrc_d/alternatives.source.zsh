alternatives::aliases () {
    grep alias ~/.zshrc_d/alternatives.source.zsh
}

alternatives::init () {
    if [[ -f /usr/bin/bat || -f /usr/local/bin/bat ]]; then
        alias Cat=/usr/bin/cat
        alias cat=bat
    fi

    if [[ -f /usr/bin/bit || -f /usr/local/bin/bit ]]; then
        alias Git=/usr/bin/git
        alias git=bit
    fi

    if [[ -f /usr/bin/procs || -f /usr/local/bin/procs ]]; then
        alias p='procs'
    fi
}

alternatives::init
