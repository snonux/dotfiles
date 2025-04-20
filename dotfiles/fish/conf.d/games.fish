function games::colorscript
    if test -e ~/git/shell-color-scripts
        cd ~/git/shell-color-scripts
        set -x DEV 1
        ./colorscript.sh --random
        cd -
    else
        echo 'No colorscripts installed. Go to:'
        echo ' https://gitlab.com/dwt1/shell-color-scripts'
    end
end

if not test -f ~/.colorscript.disable
    games::colorscript
end
