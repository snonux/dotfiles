# To run a ZSH function in fish, you can use the following function.
function Z
    touch ~/.nofish
    zsh -i -c "$argv"
    rm ~/.nofish
end
