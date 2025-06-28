if type -q zoxide
    echo Sourcing zoxide for fish shell...
    zoxide init fish | source
else
    echo "zoxide not installed?"
end
