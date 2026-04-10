abbr -a suggest hexai
abbr -a explain 'hexai explain'

if test -f ~/git/hypr/hypr.fish
    source ~/git/hypr/hypr.fish
end

set -l do_bin ~/go/bin/do

if test -x $do_bin
    $do_bin fish | source
else
    echo No $do_bin found
end
