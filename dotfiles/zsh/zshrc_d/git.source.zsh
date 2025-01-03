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

# To quickly navigate to one of the repos
git::repos::index () {
    find ~/git -type d -name .git | sed 's|/.git||' > ~/.gitrepos.index
    echo -n 'Indexed: '
    wc -l ~/.gitrepos.index
}

_git::fzf::index::cd () {
    local filter="$1"
    local filter_file=~/.gitrepos.filter
    
    if [ -z "$filter" ]; then
        filter=.
        if [ -f "$filter_file" ]; then
            filter="$(cat $filter_file)"
        fi
    elif [ "$filter" = '-' ]; then
        filter=.
        if [ -f "$filter_file" ]; then
            rm "$filter_file"
        fi
    else
        echo "$filter" > $filter_file
    fi
    
    cd "$(grep "$filter"  ~/.gitrepos.index | fzf)"
}

alias gcd=_git::fzf::index::cd
zle -N _git::fzf::index::cd
bindkey "^Gd" _git::fzf::index::cd

git::init () {
    git::fzf::init
    if [ ! where delta 2>/dev/null ]; then
        echo 'git-delta not installed'
    fi
}

git::fzf::init

