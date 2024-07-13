#!/usr/bin/env ruby

require 'optparse'

DEFAULT_TIMESPAN_D = 365
WORKTIME_DIR = "#{ENV['HOME']}/git/worktime"

def maybe? = [true, false].sample
def personal? = %x{uname}.chomp == 'Linux'

def notes(notes_dirs, dry)
  prefixes = personal? ? %w{ql pl} : %w{wl} # Quicklog, personal log or work log?
  prefixes.each do |prefix|
    notes_dirs.each do |notes_dir|
      Dir["#{notes_dir}/#{prefix}-*"].each do |notes_file|
        match = File.read(notes_file).strip.match(/(?<due>\d+)? *(?<tag>[a-z]+) *(?<body>.*)/)
        next unless match

        due = match[:due].nil? ? rand(0..DEFAULT_TIMESPAN_D) : match[:due]
        yield match[:tag], match[:body], "#{due}d"
        File.delete(notes_file) unless dry
      end
    end
  end
end

def random_quote(md_file)
  return unless maybe?
  
  tag = File.basename(md_file, '.md').downcase
  lines = File.readlines(md_file)

  match = lines.first.match(/\((\d+)\)/)
  timespan = match ? match[1].to_i : DEFAULT_TIMESPAN_D

  quote = lines.select { |l| l.start_with? '*' }
               .map { |l| l.sub(/\* +/, '') }
               .sample

  yield tag, quote.chomp, "#{rand(0..timespan)}d"
end

def run!(cmd, dry)
  puts cmd
  puts %x{#{cmd}} unless dry
end

def task_add!(tag, quote, due, dry)
  run! "task add due:#{due} +#{tag.upcase} '#{quote.gsub("'", '"')}'", dry
end

def task_schedule!(id, due, dry)
  run! "task modify #{id} due:#{due}", dry
end

def unscheduled_tasks
  lines = %x{task due:}.split("\n").drop(1)
  lines.pop
  lines.map{ |line| line.split.first }.each do |id|
    yield id if id.to_i > 0
  end  
end

begin
  opts = {
    quotes_dir: "#{ENV['HOME']}/Notes/HabitsAndQuotes",
    notes_dirs: "#{ENV['HOME']}/Notes,#{ENV['HOME']}/git/worktime",
    dry_run: false,
  }

  opt_parser = OptionParser.new do |o|
    o.banner = 'Usage: ruby taskwarriorfeeder.rb [options]'
    o.on('-d', '--quotes-dir DIR', 'The quotes directory') { |v| opts[:quotes_dir] = v }
    o.on('-n', '--notes-dirs DIR1,DIR2,...', 'The notes directories') { |v| opts[:notes_dirs] = v }
    o.on('-D', '--dry-run', 'Dry run mode') { opts[:dry_run] = true }
    o.on_tail('-h', '--help', 'Show this help message and exit') { puts o; exit }
  end

  opt_parser.parse!(ARGV)

  notes(opts[:notes_dirs].split(','), opts[:dry_run]) do |tag, note, due|
    task_add!(tag, note, due, opts[:dry_run])
  end

  Dir["#{opts[:quotes_dir]}/*.md"].each do |md_file|
    random_quote(md_file) do |tag, quote, due| 
      task_add!(tag, quote, due, opts[:dry_run])
    end
  end

  unscheduled_tasks do |id|
    task_schedule!(id, "#{rand(0..DEFAULT_TIMESPAN_D)}d", opts[:dry_run])
  end  
end
