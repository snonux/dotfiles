fish_vi_key_bindings

set -g EDITOR hx
set -g VISUAL hx

# Git stuff
abbr -a gl 'git log --pretty=oneline --graph --decorate --all'
abbr -a gp 'begin; git commit -a; and git pull; and git push; end'
