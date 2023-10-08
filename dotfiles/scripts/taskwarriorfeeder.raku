#!/usr/bin/env raku
#
# Script to move NextCloud notes to taskwarrior DB.

sub add-task(Bool:D :$dry-mode, Int:D :$due-days, Str:D :$tag, Str:D :$body --> Bool) {
  my $due-date = random-due-date $due-days == 0 ?? 365 !! $due-days;
  my @cmd = 'task', 'add', '+' ~ $tag.lc, "'{$body.subst: /\'/, '"', :g}'", $due-date;
  unshift @cmd, 'echo' if $dry-mode;
  say @cmd.join(' ');

  with run @cmd, :out {
    say .out.get;
    return .exitcode == 0;
  } 
}

sub random-due-date(Int $pick = 365 -->Str) {
    return DateTime.now(
      formatter => { sprintf 'due:%04d-%02d-%02d', .year, .month, .day }
    ).later(days => (1..$pick).pick).Str;
}

sub MAIN(:$notes-dir = %*ENV<HOME> ~ '/Notes', Bool :$dry-mode = False) {
  # Backfill all tasks from Nextcloud ~/Notes dir to taskwarrior
  for dir $notes-dir, test => { .IO.f } -> $file {
    with $file.slurp.trim {
      if / :i ^tw? \s+ $<due-days> = (\d*) \s* $<tag> = (\D+?) \s+ $<body> = (.*) $ / {
        $file.unlink if add-task :$dry-mode, due-days => +$<due-days>, tag => ~$<tag>, body => ~$<body>;
      }
    }
  }

  # Add random habits to do to taskwarrior
  my %habits := {
    'SpiritualHabits' => 'spiritual',
    'PhysicalHabits' => 'health',
    'Wisdoms' => 'wisdom',
    'Ema' => 'ema',
  }

  for %habits.kv -> $key, $tag {
    next unless Bool.pick; # Randomly do it.
    add-task :$dry-mode, :due-days(7), :$tag,
      body => "$notes-dir/HabitsAndQuotes/$key.md".IO.slurp
              .split("\n").grep( /^\* /).pick.subst('* ', '');
  }
}
