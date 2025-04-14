addon::zsh::autosuggestions::init () {
    zsh_autosuggestions_path=/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    if [ Darwin = $UNAME ]; then
        zsh_autosuggestions_path=$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    fi
    if [ -f $zsh_autosuggestions_path ]; then
        source "$zsh_autosuggestions_path"
    else
        echo 'zsh-autosuggestions not found'
    fi  
}

# Make up and down arrow take what’s typed on the commandline in to account.
# E.g. if you type ls and press up it will only find history entries that start with ls:
addon::history () {
    autoload -Uz up-line-or-beginning-search down-line-or-beginning-search

    zle -N up-line-or-beginning-search
    zle -N down-line-or-beginning-search

    bindkey '^[[A'  up-line-or-beginning-search    # Arrow up
    bindkey '^[OA'  up-line-or-beginning-search
    bindkey '^[[B'  down-line-or-beginning-search  # Arrow down
    bindkey '^[OB'  down-line-or-beginning-search
}

addon::init () {
    addon::zsh::autosuggestions::init
    addon::history
}

addon::init
