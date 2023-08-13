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

    if [[ -f /usr/bin/exa || -f /usr/local/bin/exa ]]; then
        alias Ls=/usr/bin/ls
        alias l='exa -la --icons --git --color-scale'
        alias ll='exa -la --icons --git --color-scale'
        alias tree='exa -la --tree --icons --git --color-scale'
    fi

    if [[ -f /usr/bin/procs || -f /usr/local/bin/procs ]]; then
        alias p='procs'
    fi

    if [[ -f /bin/nvim || -f /usr/bin/nvim ]]; then
        alias Vi=vi
        alias vi=nvim
        alias vim=nvim
        alias view='nvim -R'
    fi

    if [ -f /Users/pbuetow/.config/broot/launcher/bash/br ]; then
        source /Users/pbuetow/.config/broot/launcher/bash/br
    elif [ -f /home/paul/.config/broot/launcher/bash/br ]; then
        source /home/paul/.config/broot/launcher/bash/br
    fi
}

alternatives::init
