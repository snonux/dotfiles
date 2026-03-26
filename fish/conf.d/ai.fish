abbr -a suggest hexai
abbr -a explain 'hexai explain'

if test -f ~/git/hypr/hypr.fish
    source ~/git/hypr/hypr.fish
end

if test -f ~/git/hexai/assets/ask.fish
    source ~/git/hexai/assets/ask.fish
else
    echo No ~/git/hexai/assets/ask.fish found
end
