declare DOTFILES=~/git/rexfiles/dotfiles

dotfiles::update () {
    local -r prev_pwd="$(pwd)"
    cd $DOTFILES
    rex home
    cd "$prev_pwd"
}
alias .u=dotfiles::update

dotfiles::update::git () {
    local -r prev_pwd="$(pwd)"
    cd $DOTFILES
    git pull
    git commit -a
    git push
    rex home
    cd "$prev_pwd"
}
alias .ug=dotfiles::update::git

dotfiles::fuzzy::edit () {
    local -r prev_pwd="$(pwd)"
    cd $DOTFILES
    local -r dotfile="$(find . -type f -not -path '*/.git/*' | fzf)"
    $VISUAL "$dotfile"
    if grep -F -q source.zsh <<< "$dotfile"; then
        echo "Sourcing $dotfile"
        source "$dotfile"
    fi
    cd "$prev_pwd"
}
alias .e=dotfiles::fuzzy::edit

dotfiles::visual () {
    local -r prev_pwd="$(pwd)"
    cd $DOTFILES
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
  $EDITOR $(find . -type f | sort -R | head -n 1) 
}
alias .re=dotfiles::random::edit
