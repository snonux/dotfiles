games::funky () {
    while :; do 
        printf "\e[%d;%dH\e[48;5;%dm \e[0m" $(($RANDOM%$LINES)) $(($RANDOM%$COLUMNS)) $(($RANDOM%216 ))
    done
}

games::colorscript () {
    if [ -e ~/git/shell-color-scripts ]; then
        cd ~/git/shell-color-scripts
        DEV=1 ./colorscript.sh --random
        cd -
    else
        # https://gitlab.com/dwt1/shell-color-scripts
        echo 'No colorscripts installed. Go to:'
        echo ' https://gitlab.com/dwt1/shell-color-scripts'
    fi
}

if [ ! -f ~/.colorscript.disable ]; then
    games::colorscript
fi
