fish_vi_key_bindings

# Add paths to PATH
set -U fish_user_paths ~/bin ~/scripts ~/go/bin ~/.cargo/bin $fish_user_paths

if command -q -v doas >/dev/null
    abbr -a s doas
else
    abbr -a s sudo
end

abbr -a g 'grep -E -i'
abbr -a no 'grep -E -i -v'
abbr -a gl 'git log --pretty=oneline --graph --decorate --all'
abbr -a gp 'begin; git commit -a; and git pull; and git push; end'

for dir in ~/.config/fish/conf.d.work ~/.config/fish/conf.d.local
    if test -d $dir
        for file in $dir/*.fish
            source $file
        end
    end
end

if test -d /home/linuxbrew/.linuxbrew
    if status is-interactive
        # Commands to run in interactive sessions can go here
    end
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
end
