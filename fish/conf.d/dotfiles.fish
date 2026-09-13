set -gx DOTFILES_DIR ~/git/dotfiles

function dotfiles::update
    set -l prev_pwd (pwd)
    cd $DOTFILES_DIR
    ./gonf.sh home
    cd "$prev_pwd"
end

function dotfiles::update::git
    set -l prev_pwd (pwd)
    cd $DOTFILES_DIR
    git pull
    # On macOS (Darwin) this dotfiles repo is read-only: pull only, never push.
    # Host-specific changes are kept out of the public dotfiles repo.
    if test (uname) = Darwin
        echo "Darwin: skipping commit/push to dotfiles repo (pull-only)"
    else
        git commit -a
        git push
    end
    ./gonf.sh home
    cd "$prev_pwd"
end

function dotfiles::fuzzy::edit
    set -l prev_pwd (pwd)
    cd $DOTFILES_DIR
    set -l dotfile (find . -type f -not -path '*/.git/*' | fzf)
    $EDITOR "$dotfile"
    if echo "$dotfile" | grep -F -q .fish
        echo "Sourcing $dotfile"
        source "$dotfile"
    end
    cd "$prev_pwd"
end

function dotfiles::gonfify
    cd $DOTFILES_DIR
    ./gonf.sh home
    cd -
end

function dotfiles::random::edit
    $EDITOR (find $DOTFILES_DIR -type f -not -path '*/.git/*' | shuf -n 1)
end

abbr -a .u 'dotfiles::update'
abbr -a .ug 'dotfiles::update::git'
abbr -a .e 'dotfiles::fuzzy::edit'
abbr -a .gonf 'dotfiles::gonfify'
abbr -a .re 'dotfiles::random::edit'
abbr -a cdconf "cd $HOME/git/conf"
abbr -a cdotfiles "cd $HOME/git/dotfiles"
