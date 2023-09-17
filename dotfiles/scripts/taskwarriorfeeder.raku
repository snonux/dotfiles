#!/usr/bin/env raku
#
# Script to move NextCloud notes to taskwarrior DB.

our @categories = <Work Log Task Soon Habit Wisdom Now>;

sub add-task(Bool $dry-mode, Str $category, Str $content, Str $due) returns Bool {
  my $trimmed = $content.subst("'", '', :g).trim;
  my @cmd = 'task', 'add', '+' ~ $category.lc, "'$trimmed'", $due;
  unshift @cmd, 'echo' if $dry-mode;
  say @cmd.join(' ');

  with run @cmd, :out {
    say .out.get;
    return .exitcode == 0;
  }
}

sub due(Str $category) {
    my $pick = $category eq any('Soon', 'Work', 'Log') ?? 14 !!
               $category eq any('Habit', 'Now') ?? 2 !! 365;
    return DateTime.now(
      formatter => { sprintf 'due:%04d-%02d-%02d', .year, .month, .day }
    ).later(days => (1..$pick).pick).Str;
}

sub MAIN(:$notes-dir = %*ENV<HOME> ~ '/Notes', Bool :$dry-mode = False) {
  # Backfill all tasks from Nextcloud ~/Notes dir to taskwarrior
  for dir $notes-dir, test => { .IO.f } -> $file {
    my $content = $file.slurp.split("\n");
    my $category = $content.split(' ', 2).first;
    next unless $category eq any(@categories);

    $content = $content.subst($category, '').trim;
    $file.unlink if add-task $dry-mode, $category, $content, due($category) and !$dry-mode;
  }

  # Add random habits to do to taskwarrior
  my %habits := {
    'SpiritualHabits' => 'Habit',
    'PhysicalHabits' => 'Habit',
    'Wisdoms' => 'Wisdom',
  }

  my @habits = gather {
    for %habits.kv -> $k, $v {
      next unless Bool.pick; # Randomly do it.
      take my $random-habit = "$notes-dir/HabitsAndQuotes/$k.md".IO.slurp.split("\n").grep( /^\* /).pick.subst('* ', '');
      add-task $dry-mode, $v, $random-habit, due($v);
    }
  }

  .say for @habits;
}
