export EDITOR=hx
export VISUAL=$EDITOR
export GIT_EDITOR=$EDITOR

editor::helix::random_theme () {
    local theme_dir=/usr/share/helix/runtime/themes

    if [ ! -d $theme_dir ]; then
        return
    fi

    local random_theme=$(ls $theme_dir | grep -v random.toml | grep .toml | sort -R | head -n 1)
    cp $theme_dir/$random_theme $theme_dir/random.toml
}

if [ $UNAME = Linux ]; then
    editor::helix::random_theme
fi

alias vi=$EDITOR
