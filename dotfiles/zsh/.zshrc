if [ -f $HOME/.nofish ]; then
   current_time=$(date +%s)
   file_time=$(stat -f %m $HOME/.nofish)
   time_diff=$((current_time - file_time))
   if [ $time_diff -gt 3600 ]; then
      rm -vf $HOME/.nofish
   fi
fi
if [ ! -f $HOME/.nofish ]; then
  if [ -e /opt/homebrew/bin/fish ]; then
    exec /opt/homebrew/bin/fish
  elif [ -e /bin/fish ]; then
    exec /bin/fish
  elif [ -e /usr/bin/fish ]; then
    exec /usr/bin/fish
  elif [ -e /data/data/com.termux/files/usr/bin/fish ]; then
    exec /data/data/com.termux/files/usr/bin/fish
  fi
  echo 'I might want to install fish on this host'
fi

alias f=fish
