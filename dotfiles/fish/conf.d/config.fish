fish_vi_key_bindings

# Add paths to PATH
set -U fish_user_paths ~/bin ~/go/bin ~/.cargo/bin $fish_user_paths

abbr -a s sudo

# Git stuff
abbr -a gl 'git log --pretty=oneline --graph --decorate --all'
abbr -a gp 'begin; git commit -a; and git pull; and git push; end'

for dir in ~/.config/fish/conf.d.work ~/.config/fish/conf.d.local
    if test -d $dir
        for file in $dir/*.fish
            source $file
        end
    end
end
