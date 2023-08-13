#!/usr/bin/env raku
#
# Script to move NextCloud notes to taskwarrior DB.

our @categories = <Work Log Task Soon Habit Wisdom>;

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
    my $pick = $category eq any('Soon', 'Work') ?? 14 !!
               $category eq 'Habit' ?? 2 !! 365 * 2;
    return DateTime.now(
      formatter => { sprintf 'due:%04d-%02d-%02d', .year, .month, .day }
    ).later(days => (1..$pick).pick).Str;
}

sub MAIN(:$notes-dir = %*ENV<HOME> ~ '/Notes', Bool :$dry-mode = False) {
  for dir $notes-dir, test => { .IO.f } -> $file {
    my $content = $file.slurp.split("\n");
    my $category = $content.split(' ', 2).first;
    next unless $category eq any(@categories);

    $content = $content.subst($category, '').trim;
    $file.unlink if add-task $dry-mode, $category, $content, due($category) and !$dry-mode;
  }

  my $random-habit = "$notes-dir/HabitsAndQuotes/Habits.md"
                     .IO.slurp.split("\n").grep( /^\* /).pick.subst('* ', '');
  add-task $dry-mode, 'Habit', $random-habit, due('Habit');

  my $random-wisdom = "$notes-dir/HabitsAndQuotes/Wisdoms.md"
                     .IO.slurp.split("\n").grep( /^\* /).pick.subst('* ', '');
  add-task $dry-mode, 'Wisdom', $random-wisdom, due('Wisdom');
}
