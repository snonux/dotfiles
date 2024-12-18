export EDITOR=hx
export VISUAL=$EDITOR
export GIT_EDITOR=$EDITOR
export HELIX_CONFIG_DIR=$HOME/.config/helix

editor::helix::theme::get_random () {
    for dir in $(hx --health \
        | awk '/^Runtime directories/ { print $3 }' | tr ';' ' '); do
        if [ -d $dir/themes ]; then
            ls $dir/themes
        fi
    done | grep -F .toml | sort -R | head -n 1 | cut -d. -f1
}

editor::helix::theme::set () {
    local -r theme="$1"; shift

    local -r config_file=$HELIX_CONFIG_DIR/config.toml

    sed "/^theme =/ { s/.*/theme = \"$theme\"/; }" \
        $config_file > $config_file.tmp && 
        mv $config_file.tmp $config_file
}

if [ -f $HELIX_CONFIG_DIR/config.toml ]; then
    editor::helix::theme::set $(editor::helix::theme::get_random)
fi

alias -s txt=$EDITOR
alias -s pp=$EDITOR
alias -s json=$EDITOR
alias -s xml=$EDITOR
alias -s erb=$EDITOR
alias -s c=$EDITOR
alias -s rb=$EDITOR
