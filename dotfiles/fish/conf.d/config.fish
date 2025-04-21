fish_vi_key_bindings

# Add paths to PATH
set -U fish_user_paths ~/bin ~/go/bin ~/.cargo/bin $fish_user_paths

if command -q -v doas >/dev/null
    abbr -a s doas
else
    abbr -a s sudo
end

abbr -a g 'grep -E -i'
abbr -a no 'grep -E -i -v'
abbr -a gl 'git log --pretty=oneline --graph --decorate --all'
abbr -a gp 'begin; git commit -a; and git pull; and git push; end'

# TODO: Rewrite, to use $fish_function_path
# Apparently, the conf.d directories are set up by fisher?
# Maybe use ~/confg/fish/functions/ instead?
for dir in ~/.config/fish/conf.d.work ~/.config/fish/conf.d.local
    if test -d $dir
        for file in $dir/*.fish
            source $file
        end
    end
end
