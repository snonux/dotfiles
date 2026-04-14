abbr -a suggest hexai
abbr -a explain 'hexai explain'

if test -f ~/git/hypr/hypr.fish
    source ~/git/hypr/hypr.fish
end

set -l ask_bin ~/go/bin/ask

if test -x $ask_bin
    $ask_bin fish | source
else
    echo No $ask_bin found
end
