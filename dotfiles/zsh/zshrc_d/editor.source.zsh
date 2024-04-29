export EDITOR=nvim
export VISUAL=$EDITOR
export GIT_EDITOR=$EDITOR

editor::nvim::cd () {
    cd ~/.config/nvim
}

alias vi=$EDITOR
alias cdvi=editor::nvim::cd
alias fvi="$EDITOR \"\$(find . -type f | fzf)\""
