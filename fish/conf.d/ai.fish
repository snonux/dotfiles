function kimi
    ollama launch opencode --model kimi-k2.6:cloud -y -- run "$1"
end

function glm
    ollama launch opencode --model glm-5.1:cloud -y -- run "$1"
end

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
