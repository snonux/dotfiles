pass::commit () {
    cd ~/.password-store || return 3
    git add -A .
    git commit -a -m "@$"
    cd - &>/dev/null
}

pass::push () {
    cd ~/.password-store || return 3
    git push $@
    cd - &>/dev/null
}

pw () {
    if [ $1 = commit ]; then
        shift
        pass::commit $@
    elif [ $1 = push ]; then
        shift
        pass::push $@
    elif [ $1 = new ]; then
        shift
        pass::commit $@
        pass::push origin master
    elif [ $1 = s ]; then
        shift
        pass search $@
    else
        pass $@
    fi
}

if [ -f ~/git/geheim/geheim.rb ]; then
    alias geheim='ruby ~/git/geheim/geheim.rb'
    geheim::setpin () {
        read PIN
        export PIN
    }
fi

