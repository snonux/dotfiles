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
