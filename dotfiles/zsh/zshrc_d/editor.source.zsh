export EDITOR=hx
export VISUAL=$EDITOR
export GIT_EDITOR=$EDITOR
export HELIX_CONFIG_DIR=$HOME/.config/helix

editor::helix::random_theme () {
    # May add more theme search paths based on OS. This one is
    # for Fedora Linux, but there is also MacOS, etc.
    local -r theme_dir=/usr/share/helix/runtime/themes
    if [ ! -d $theme_dir ]; then
        echo "Helix theme dir $theme_dir doesnt exist"
        return 1
    fi

    local -r config_file=$HELIX_CONFIG_DIR/config.toml
    local -r random_theme="$(basename "$(ls $theme_dir \
        | grep -v random.toml | grep .toml | sort -R \
        | head -n 1)" | cut -d. -f1)"

    sed "/^theme =/ { s/.*/theme = \"$random_theme\"/; }" \
        $config_file > $config_file.tmp && 
        mv $config_file.tmp $config_file
}

if [ -f $HELIX_CONFIG_DIR/config.toml ]; then
    editor::helix::random_theme
fi

alias -s txt=$EDITOR
alias -s pp=$EDITOR
alias -s json=$EDITOR
alias -s xml=$EDITOR
alias -s erb=$EDITOR
alias -s c=$EDITOR
alias -s rb=$EDITOR
