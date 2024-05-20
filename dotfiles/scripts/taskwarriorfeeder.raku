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

sub add-notes(Str $dir, Bool :$dry-mode) {
  for dir $dir, test => { /pl\-.*\./ } -> $file {
    with $file.slurp.trim {
      if / :i ^ $<due-days> = (\d*) \s* $<tag> = (\D+?) \s+ $<body> = (.*) $ / {
        $file.unlink if add-task :$dry-mode, due-days => +$<due-days>, tag => ~$<tag>, body => ~$<body>;
      }
    }
  }
}

sub MAIN(:$notes-dir = %*ENV<HOME> ~ '/Notes', :$worktime-dir = %*ENV<HOME> ~ '/git/worktime', Bool :$dry-mode = False) {
  add-notes $notes-dir, :$dry-mode;
  add-notes $worktime-dir, :$dry-mode;

  # Add random habits to do to taskwarrior
  my %habits := {
    'ScoreWoman' => 'relationship',
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
