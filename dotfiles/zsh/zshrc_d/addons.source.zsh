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

addon::init () {
  addon::zsh::autosuggestions::init
}

addon::init
