games::funky () {
    while :; do 
        printf "\e[%d;%dH\e[48;5;%dm \e[0m" $(($RANDOM%$LINES)) $(($RANDOM%$COLUMNS)) $(($RANDOM%216 ))
    done
}

games::colorscript () {
    if [ -f /usr/bin/colorscript ]; then
        /usr/bin/colorscript --random
    elif [ -f ~/bin/colorscript ]; then
        ~/bin/colorscript --random
    else
        # https://gitlab.com/dwt1/shell-color-scripts
        echo 'No colorscripts installed. Go to:'
        echo ' https://gitlab.com/dwt1/shell-color-scripts'
    fi
}

if [ ! -f ~/.colorscript.disable ]; then
    games::colorscript
fi
