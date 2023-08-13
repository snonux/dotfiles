if [[ $UNAME_R =~ Microsoft ]]; then
    winopen () {
        local -r file=$(readlink -f "$1" | sed 's/\//\\/g')
        cmd.exe /c start "%localappdata%\\lxss\\$file"
    }
fi
