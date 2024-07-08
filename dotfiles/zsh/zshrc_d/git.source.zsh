git::log () {
    git log --graph --decorate --all
}

git::log::oneline () {
    git log --pretty=oneline --graph --decorate --all
}
alias gl=git::log::oneline

# Delete local branches which were merged into master.
git::prune () {
    git branch --merged master | grep -F -v master | xargs -n 1 git branch -d
}

git::quickpush () {
    git commit -a
    git pull
    git push
}
alias gp=git::quickpush


git::fzf::init () {
    # Uses `bat` command for syntax highlighting
    if [ -f ~/git/fzf-git.sh/fzf-git.sh ]; then
        source ~/git/fzf-git.sh/fzf-git.sh
        return
    fi    
    echo 'fzf-git not on this system'
}

git::init () {
    git::fzf::init
    if [ ! where delta 2>/dev/null ]; then
        echo 'git-delta not installed'
    fi
}

git::init

