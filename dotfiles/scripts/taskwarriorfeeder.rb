#!/usr/bin/env ruby

require 'optparse'

PERSONAL_TIMESPAN_D = 365
WORK_TIMESPAN_D = 14
WORKTIME_DIR = "#{ENV['HOME']}/git/worktime".freeze

def maybe?
  [true, false].sample
end

def personal?
  %x(uname).chomp == 'Linux'
end

def notes(notes_dirs, prefix, dry)
  notes_dirs.each do |notes_dir|
    Dir["#{notes_dir}/#{prefix}-*"].each do |notes_file|
      match = File.read(notes_file).strip.match(/(?<due>\d+)? *(?<tag>[a-z]+) *(?<body>.*)/)
      next unless match

      due = match[:due].nil? ? rand(0..PERSONAL_TIMESPAN_D) : match[:due]
      yield [match[:tag],prefix], match[:body], "#{due}d"
      File.delete(notes_file) unless dry
    end
  end
end

def random_quote(md_file)
  tag = File.basename(md_file, '.md').downcase
  lines = File.readlines(md_file)

  match = lines.first.match(/\((\d+)\)/)
  timespan = personal? ? PERSONAL_TIMESPAN_D : WORK_TIMESPAN_D
  timespan = match ? match[1].to_i : timespan

  quote = lines.select { |l| l.start_with? '*' }.map { |l| l.sub(/\* +/, '') }.sample
  yield [tag, 'random'], quote.chomp, "#{rand(0..timespan)}d"
end

def run!(cmd, dry)
  puts cmd
  puts %x(#{cmd}) unless dry
end

def worklog_add!(tag, quote, due, dry)
  file = "#{WORKTIME_DIR}/wl-#{Time.now.to_i}n.txt"
  content = "#{due.chomp 'd'} #{tag} #{quote}"

  puts "#{file}: #{content}"
  File.write(file, content) unless dry
end

def task_add!(tags, quote, due, dry)
  run! "task add due:#{due} +#{tags.join(' +')} '#{quote.gsub("'", '"')}'", dry
end

def task_schedule!(id, due, dry)
  run! "task modify #{id} due:#{due}", dry
end

def unscheduled_tasks
  lines = %x(task due:).split("\n").drop(1)
  lines.pop
  lines.map { |line| line.split.first }.each do |id|
    yield id if id.to_i.positive?
  end
end

begin
  opts = {
    quotes_dir: "#{ENV['HOME']}/Notes/HabitsAndQuotes",
    notes_dirs: "#{ENV['HOME']}/Notes,#{ENV['HOME']}/git/worktime",
    dry_run: false
  }

  opt_parser = OptionParser.new do |o|
    o.banner = 'Usage: ruby taskwarriorfeeder.rb [options]'
    o.on('-d', '--quotes-dir DIR', 'The quotes directory') { |v| opts[:quotes_dir] = v }
    o.on('-n', '--notes-dirs DIR1,DIR2,...', 'The notes directories') { |v| opts[:notes_dirs] = v }
    o.on('-D', '--dry-run', 'Dry run mode') { opts[:dry_run] = true }
    o.on_tail('-h', '--help', 'Show this help message and exit') { puts o and exit }
  end

  opt_parser.parse!(ARGV)

  (personal? ? %w[ql pl] : %w[wl]).each do |prefix|
    notes(opts[:notes_dirs].split(','), prefix, opts[:dry_run]) do |tags, note, due|
      if tags.include? 'WORK'
        worklog_add!(:log, note, due, opts[:dry_run])
      else
        task_add!(tags, note, due, opts[:dry_run])
      end
    end
  end

  Dir["#{opts[:quotes_dir]}/*.md"].each do |md_file|
    next unless maybe? and maybe? # Double maybe 

    random_quote(md_file) do |tags, quote, due|
      task_add!(tags, quote, due, opts[:dry_run])
    end
  end

  unscheduled_tasks do |id|
    task_schedule!(id, "#{rand(0..PERSONAL_TIMESPAN_D)}d", opts[:dry_run])
  end
end
