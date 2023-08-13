declare DOTFILES=~/git/rexfiles

dotfiles::update () {
  local -r prev_pwd="$(pwd)"
  cd $DOTFILES
  rex home
  cd "$prev_pwd"
}
alias .u=dotfiles::update

dotfiles::update::git () {
  local -r prev_pwd="$(pwd)"
  cd $DOTFILES
  git pull
  git commit -a -m 'update'
  git push
  rex home
  cd "$prev_pwd"
}
alias .ug=dotfiles::update::git

dotfiles::fuzzy::edit () {
  local -r prev_pwd="$(pwd)"
  cd $DOTFILES
  local -r dotfile="$(find . -type f -not -path '*/.git/*' | fzf)"
  $VISUAL "$dotfile"
  if grep -F -q source.zsh <<< "$dotfile"; then
    source "$dotfile"
  fi
  cd "$prev_pwd"
}
alias .e=dotfiles::fuzzy::edit

dotfiles::visual () {
  local -r prev_pwd="$(pwd)"
  cd $DOTFILES
  $VISUAL
  cd "$prev_pwd"
}
alias .v=dotfiles::visual

#dotfiles::backup::helix () {
#  local -r prev_pwd="$(pwd)"
#  cd ~/git/rexfiles/dotfiles/helix &&
#    cp ~/.config/helix/*.toml . &&
#    git add *.toml &&
#    git commit -m "Updating Helix config" *.toml
#  git pull
#  git push
#  cd "$prev_pwd"
#}
#alias .hx=dotfiles::backup::helix

dotfiles::rexify () {
  local -r prev_pwd="$(pwd)"
  cd ~/git/rexfiles/dotfiles/
  rex home
  cd "$prev_pwd"
}
alias .rex=dotfiles::rexify
