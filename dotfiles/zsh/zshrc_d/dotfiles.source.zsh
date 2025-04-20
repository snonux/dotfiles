export DOTFILES_DIR=~/git/rexfiles/dotfiles

dotfiles::update () {
    local -r prev_pwd="$(pwd)"
    cd $DOTFILES_DIR
    rex home
    cd "$prev_pwd"
}
alias .u=dotfiles::update

dotfiles::update::git () {
    local -r prev_pwd="$(pwd)"
    cd $DOTFILES_DIR
    git pull
    git commit -a
    git push
    rex home
    loadzsh
    cd "$prev_pwd"
}
alias .ug=dotfiles::update::git

dotfiles::fuzzy::edit () {
    local -r prev_pwd="$(pwd)"
    cd $DOTFILES_DIR
    local -r dotfile="$(find . -type f -not -path '*/.git/*' | fzf)"
    $EDITOR "$dotfile"
    if grep -F -q source.zsh <<< "$dotfile"; then
        echo "Sourcing $dotfile"
        source "$dotfile"
    fi
    cd "$prev_pwd"
}
alias .e=dotfiles::fuzzy::edit

dotfiles::visual () {
    local -r prev_pwd="$(pwd)"
    cd $DOTFILES_DIR
    $VISUAL
    cd "$prev_pwd"
}
alias .v=dotfiles::visual

dotfiles::rexify () {
    local -r prev_pwd="$(pwd)"
    cd ~/git/rexfiles/dotfiles/
    rex home
    cd "$prev_pwd"
}
alias .rex=dotfiles::rexify

dotfiles::random::edit () {
    cd $DOTFILES_DIR
    $EDITOR $(find . -type f | sort -R | head -n 1) 
    cd -
}
alias .re=dotfiles::random::edit
