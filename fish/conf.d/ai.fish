function kimi
    ollama launch opencode --model kimi-k2.6:cloud -y -- run $argv
end

function glm
    ollama launch opencode --model glm-5.1:cloud -y -- run $argv
end

function qwen
    ollama launch opencode --model qwen3.5:cloud -y -- run $argv
end

abbr -a suggest hexai
abbr -a explain 'hexai explain'
abbr -a research 'hexai research'

if test -f ~/git/hypr/hypr.fish
    source ~/git/hypr/hypr.fish
end

set -l ask_bin ~/go/bin/ask

if test -x $ask_bin
    $ask_bin fish | source
else
    echo No $ask_bin found
end
