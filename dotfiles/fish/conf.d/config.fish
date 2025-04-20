fish_vi_key_bindings

# Add paths to PATH
set -U fish_user_paths ~/bin ~/go/bin ~/.cargo/bin $fish_user_paths

# Git stuff
abbr -a gl 'git log --pretty=oneline --graph --decorate --all'
abbr -a gp 'begin; git commit -a; and git pull; and git push; end'
