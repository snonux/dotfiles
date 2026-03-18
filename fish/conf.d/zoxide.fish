if type -q zoxide
    zoxide init fish | source
else
    echo "zoxide not installed?"
end

abbr z zi
