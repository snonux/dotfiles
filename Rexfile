use Rex -feature => [ '1.14', 'exec_autodie' ];
use Rex::Logger;

our $HOME = $ENV{HOME};

# In a public Git rapository.
our $DOT = "$HOME/git/dotfiles";

# In a private Git repository.
our $DOT_PRIVATE = "$HOME/git/conf_private/dotfiles";

sub ensure_dir {
    my ( $src_glob, $dst_dir, $file_mode ) = @_;
    Rex::Logger::info("Ensure dir glob $src_glob");

    file $dst_dir,
      ensure => 'directory',
      mode   => '0700';

    file "$dst_dir/" . basename($_),
      ensure => 'present',
      source => $_,
      mode   => $file_mode // '0640'
      for glob $src_glob;
}

# Remove regular files in $dst_dir whose basename is not produced by
# $src_glob. Dotfiles and subdirectories are left untouched so that
# tool-generated state (e.g. .claude, .ruby-lsp) is preserved.
sub prune_dir {
    my ( $src_glob, $dst_dir ) = @_;
    return unless -d $dst_dir;

    my %keep = map { basename($_) => 1 } glob $src_glob;

    for my $path ( glob "$dst_dir/*" ) {
        next unless -f $path;
        my $name = basename($path);
        next if $keep{$name};

        Rex::Logger::info("Pruning stale file $path");
        file $path, ensure => 'absent';
    }
}

sub ensure_file {
    my ( $src_file, $dst_file, $file_mode ) = @_;

    file $dst_file,
      ensure => 'present',
      source => $src_file,
      mode   => $file_mode // '0640';
}

sub ensure {
    my ( $src, $dst, $mode ) = @_;
    ( $dst =~ /\/$/ ? \&ensure_dir : \&ensure_file )->( $src, $dst, $mode );
}


desc 'Install packages on Termux';
task 'pkg_termux', sub {
    my @pkgs = qw/
      ack-grep
      ctags
      fzf
      golang
      htop
      make
      nodejs
      ripgrep
      rsync
      ruby
      starship
      tig
      /;

    for my $pkg (@pkgs) {
        Rex::Logger::info("Installing package $pkg");
        pkg $pkg, ensure => 'installed';
    }
};

desc 'Install packages on FreeBSD';
task 'pkg_freebsd', sub {
    my @pkgs = qw/
      zoxide
      dust
      lazygit
      taskwarrior
      bat
      ctags
      fzf
      gmake
      go
      gron
      htop
      lynx
      node
      p5-ack
      ripgrep
      tig
      doas
      tmux
      /;

    for my $pkg (@pkgs) {
        Rex::Logger::info("Installing package $pkg");
        pkg $pkg, ensure => 'installed';
    }
};

desc 'Install packages on Fedora Linux';
task 'pkg_fedora', sub {
    my @pkgs = qw/
      opendoas
      fd-find
      nodejs-bash-language-server
      fortune-mod
      syncthing
      ncdu
      ack
      fish
      bat
      ctags
      fzf
      golang
      golang-x-tools-gopls
      gpaste
      gron
      htop
      java-latest-openjdk-devel
      lynx
      make
      nodejs
      perl-File-Slurp
      procs
      rakudo
      Rex
      ripgrep
      ruby
      strace
      task2
      tig
      tmux
      dialect
      chromium
      strawberry
      gnumeric
      sway-config-fedora
      sway
      waybar
      zathura
      /;

    for my $pkg (@pkgs) {
        Rex::Logger::info("Installing package $pkg");
        pkg $pkg, ensure => 'installed';
    }
};

desc 'Install ~/.config/helix';
task 'home_helix', sub { ensure "$DOT/helix/*" => "$HOME/.config/helix/" };

desc 'Install ~/.config/ghostty';
task 'home_ghostty', sub { ensure "$DOT/ghostty/*" => "$HOME/.config/ghostty/" };

desc 'Install ~/.config/hexai (Linux only)';
task 'home_hexai', sub {
    if ( $^O eq 'linux' ) {
        ensure "$DOT/hexai/*" => "$HOME/.config/hexai/";
    }
    else {
        Rex::Logger::info( 'Skipping hexai configuration (not on Linux)', 'warn' );
    }
};

desc 'Install ~/.config/lazygit';
task 'home_lazygit', sub { ensure "$DOT/lazygit/*" => "$HOME/.config/lazygit/" };

desc 'Install ~/.config/opencode';
task 'home_opencode', sub { ensure "$DOT/opencode/*" => "$HOME/.config/opencode/" };

desc 'Install prompt links for AI tools';
task 'home_prompts', sub {
    if ( -d "$HOME/Notes/Prompts/commands" ) {
        Rex::Logger::info("Installing prompt links");

        my $ensure_symlink = sub {
            my ( $source, $target, $label ) = @_;

            if ( -l $target ) {
                my $existing = readlink $target;
                if ( defined $existing && $existing eq $source ) {
                    return;
                }
                CORE::unlink($target) or die "Could not replace $label symlink at $target: $!";
            }
            elsif ( -d $target ) {
                my ($leaf) = $target =~ m{([^/]+)$};
                my $nested = "$target/$leaf";
                if ( -l $nested && readlink($nested) eq $source ) {
                    CORE::unlink($nested) or die "Could not remove nested $label symlink at $nested: $!";
                    rmdir $target         or die "Could not remove legacy $label directory at $target: $!";
                }
                else {
                    die "Refusing to overwrite existing directory at $target while linking $label";
                }
            }
            elsif ( -e $target ) {
                die "Refusing to overwrite existing path at $target while linking $label";
            }

            symlink $source => $target or die "Could not create $label symlink ($source -> $target): $!";
        };

        # For most agents, commands and skills live under ~/.<tool>/{commands,skills}.
        my @tool_dirs = ( '.cursor', '.claude', '.agents', '.opencode' );

        for my $tool_dir (@tool_dirs) {
            file "$HOME/$tool_dir" => ensure => 'directory', mode => '0750';

            $ensure_symlink->( "$HOME/Notes/Prompts/commands", "$HOME/$tool_dir/commands", "$tool_dir commands" );
            $ensure_symlink->( "$HOME/Notes/Prompts/skills",   "$HOME/$tool_dir/skills",   "$tool_dir skills" );
        }

        # Codex CLI custom slash commands are loaded from ~/.codex/prompts.
        file "$HOME/.codex" => ensure => 'directory', mode => '0750';
        $ensure_symlink->( "$HOME/Notes/Prompts/commands", "$HOME/.codex/prompts", ".codex prompts" );
    }
    else {
        Rex::Logger::info("Not installing prompt links");
    }
};

desc 'Install ~/scripts';
task 'home_scripts', sub {
    ensure "$DOT/scripts/*" => "$HOME/scripts/", '0750';
    prune_dir "$DOT/scripts/*" => "$HOME/scripts";
};

desc 'Install ~/.ssh files';
task 'home_ssh', sub { ensure "$DOT/ssh/config" => "$HOME/.ssh/config", '0600' };

desc 'Install BASH configuration';
task 'home_bash', sub {
    ensure "$DOT/bash/bash_profile" => "$HOME/.bash_profile";
    ensure "$DOT/bash/bashrc"       => "$HOME/.bashrc";
};

desc 'Install ZSH configuration';
task 'home_zsh', sub {
    if ( $^O eq 'darwin' ) {
        ensure "$DOT/zsh/zshrc" => "$HOME/.zshrc";
    }
    else {
        Rex::Logger::info( 'Skipping ZSH configuration (not on macOS)', 'warn' );
    }
};

desc 'Install fish configuration';
task 'home_fish', sub {

    # ensure "$DOT/fish/conf.d/*" => "$HOME/.config/fish/conf.d/";
    my $dest_dir = "$HOME/.config/fish/conf.d";
    if ( !-l $dest_dir ) {
        if ( -d $dest_dir ) {
            rename $dest_dir, "$dest_dir.old" or die "Could not rename $dest_dir: $!";
        }
        symlink "$DOT/fish/conf.d" => $dest_dir or die "Could not create symlink: $!";
    }
};

desc 'Install gitsyncer configuration';
task 'home_gitsyncer', sub {
    my $dest_dir = "$HOME/.config/gitsyncer";
    symlink "$DOT/gitsyncer/" => $dest_dir or die "Could not create symlink: $!";
};

sub isFileSymlink() {
    my $file = shift;
    return -l $file && -e $file;
}

desc 'Vale and proselint';
task 'home_vale', sub {
    ensure "$DOT/vale.ini" => "$HOME/.vale.ini";
    say 'Now you can run "vale sync"';
};

desc 'Install tmux configuration';
task 'home_tmux', sub {
    ensure "$DOT/tmux/*" => "$HOME/.config/tmux/";
};

desc 'Install tmux rocky overrides (C-g prefix for nested tmux)';
task 'home_tmux_rocky', sub {
    if ( $^O eq 'linux' ) {
        my $hostname = `hostname 2>/dev/null` // '';
        chomp $hostname;
        if ( $hostname =~ /rocky/ ) {
            my $line = "source-file ~/.config/tmux/tmux.rocky.conf";
            my $local_conf = "$HOME/.config/tmux/tmux.local.conf";
            my $main_conf  = "$HOME/.config/tmux/tmux.conf";

            # Clean up stale reference from tmux.local.conf (moved to end of tmux.conf)
            if ( -f $local_conf ) {
                my $content = do { local $/; open my $fh, '<', $local_conf or die $!; <$fh> };
                if ( $content =~ /\Q$line\E/ ) {
                    $content =~ s/\n*\Q$line\E\n*/\n/;
                    open my $fh, '>', $local_conf or die $!;
                    print $fh $content;
                    close $fh;
                    Rex::Logger::info("Removed stale tmux.rocky.conf source from $local_conf");
                }
            }

            # Append to the END of tmux.conf so rocky colors override shared config
            if ( -f $main_conf ) {
                my $content = do { local $/; open my $fh, '<', $main_conf or die $!; <$fh> };
                if ( $content !~ /\Q$line\E/ ) {
                    Rex::Logger::info("Appending tmux.rocky.conf source to end of $main_conf");
                    open my $fh, '>>', $main_conf or die $!;
                    print $fh "\n$line\n";
                    close $fh;
                }
                else {
                    Rex::Logger::info("tmux.rocky.conf already sourced in $main_conf");
                }
            }
        }
        else {
            Rex::Logger::info( 'Skipping tmux rocky overrides (not on rocky)', 'warn' );
        }
    }
    else {
        Rex::Logger::info( 'Skipping tmux rocky overrides (not on linux)', 'warn' );
    }
};

desc 'Install Sway configuration';
task 'home_sway', sub {
    ensure "$DOT/sway/config.d/*" => "$HOME/.config/sway/config.d/";
    ensure "$DOT/waybar/*"        => "$HOME/.config/waybar/";
};

desc 'Install global git configuration';
task 'home_gitconfig', sub {
    if ( $^O eq 'linux' ) {
        my %config = (
            'user.email'                => 'paul@buetow.org',
            'user.name'                 => 'Paul Buetow',
            'init.defaultbranch'        => 'main',
            'core.editor'              => 'hx',
            'core.pager'               => 'delta',
            'delta.navigate'           => 'true',
            'delta.side-by-side'       => 'true',
            'delta.features'           => 'side-by-side line-numbers decorations',
            'commit.verbose'           => 'true',
            'interactive.difffilter'   => 'delta --color-only',
            'diff.tool'                => 'difftastic',
            'difftool.prompt'          => 'false',
            'difftool.difftastic.cmd'  => 'difft $LOCAL $REMOTE',
        );

        for my $key ( sort keys %config ) {
            Rex::Logger::info("Setting git config $key");
            run "git config --global '$key' '$config{$key}'";
        }
    }
    else {
        Rex::Logger::info( 'Skipping git configuration (not on Linux)', 'warn' );
    }
};

desc 'Install my signature';
task 'home_signature', sub {
    ensure "$DOT/signature" => "$HOME/.signature";
};

desc 'Install my calendar files';
task 'home_calendar', sub {
    unless ( -d $DOT_PRIVATE ) {
        Rex::Logger::info( "$DOT_PRIVATE not there, skipping task", 'warn' );
    }
    else {
        ensure "$DOT_PRIVATE/calendar/*" => "$HOME/.calendar/";
    }
};

desc 'Install my Pipewire tuned for High-Res config';
task 'home_pipewire', sub {
    file "$HOME/.config/pipewire" => ensure => 'directory',
      mode                        => '0750';
    ensure
      "$DOT/pipewire/pipewire.conf" => "$HOME/.config/pipewire/pipewire.conf",
      '0600';
};

desc 'Manage ~/QuickEdit directory and symlinks';
task 'home_quickedit', sub {
    if ( $^O eq 'linux' || $^O eq 'freebsd' ) {
        Rex::Logger::info('Setting up ~/QuickEdit');

        file "$HOME/QuickEdit",
          ensure => 'directory',
          mode   => '0700';

        my %symlinks = (
            'data'             => "$HOME/data/",
            'Documents'        => "$HOME/Documents//",
            'dotfiles'         => "$HOME/git/dotfiles/",
            'foo.zone-gemtext' => "$HOME/git/foo.zone-content/gemtext//",
            'Notes'            => "$HOME/Notes/",
            'public-snippets'  => "$HOME/git/conf/snippets//",
            'worktime'         => "$HOME/git/worktime/",
        );

        for my $name ( keys %symlinks ) {
            my $link_path = "$HOME/QuickEdit/$name";
            my $target    = $symlinks{$name};

            # Remove existing symlink if it points to a different target
            if ( -l $link_path ) {
                my $current_target = readlink($link_path);
                if ( $current_target ne $target ) {
                    unlink $link_path or die "Could not remove $link_path: $!";
                    symlink $target => $link_path or die "Could not create symlink $link_path: $!";
                }
            }
            elsif ( -e $link_path ) {
                Rex::Logger::info( "$link_path exists but is not a symlink, skipping", 'warn' );
            }
            else {
                symlink $target => $link_path or die "Could not create symlink $link_path: $!";
            }
        }
    }
    elsif ( $^O eq 'darwin' ) {
        Rex::Logger::info('QuickEdit placeholder for macOS (not yet implemented)');

        # TODO: Implement QuickEdit management for macOS
    }
};

desc 'Install systemd user units';
task 'home_systemd_user', sub {
    my $dst_dir = "$HOME/.config/systemd/user";

    file $dst_dir,
      ensure => 'directory',
      mode   => '0700';

    for my $file ( glob "${DOT}/systemd-user/*" ) {
        file "$dst_dir/" . basename($file),
          ensure => 'present',
          source => $file,
          mode   => '0640';
    }

    # Reload systemd user daemon to pick up any new or changed units.
    Rex::Logger::info('Reloading systemd user daemon');
    run 'systemctl --user daemon-reload';

    # Enable the random-wallpaper timer so it starts on login.
    Rex::Logger::info('Enabling random-wallpaper.timer');
    run 'systemctl --user enable random-wallpaper.timer';
};

desc 'Install all my ~ files';
task 'home', sub {
    require Rex::TaskList;
    run_task $_ for Rex::TaskList->create()->get_all_tasks('^home_');
};


desc 'Install packages on Rocky Linux';
task 'pkg_rocky', sub {
    my @pkgs = qw/
      fd-find
      ncdu
      ack
      fish
      bat
      ctags
      fzf
      golang
      htop
      java-latest-openjdk-devel
      lynx
      make
      nodejs
      ripgrep
      ruby
      strace
      zoxide
      tig
      tmux
      vim-enhanced
      git
      /;

    for my $pkg (@pkgs) {
        Rex::Logger::info("Installing package $pkg");
        pkg $pkg, ensure => "installed";
    }
};
