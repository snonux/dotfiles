where starship &>/dev/null
if [ $? -eq 0 ]; then
    eval "$(starship init zsh)"
fi
