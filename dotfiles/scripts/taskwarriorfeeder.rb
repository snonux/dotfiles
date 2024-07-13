#!/usr/bin/env ruby

require 'optparse'

DEFAULT_TIMESPAN_D = 365

def notes(notes_dirs, dry)
  notes_dirs.each do |notes_dir|
    Dir["#{notes_dir}/ql-*"].each do |notes_file|
      match = File.read(notes_file).strip.match(/(?<due>\d+)? *(?<tag>[a-z]+) *(?<body>.*)/)
      next unless match

      due = match[:due].nil? ? rand(0..DEFAULT_TIMESPAN_D) : match[:due]
      yield match[:tag], match[:body], "#{due}d"
      File.delete(notes_file) unless dry
    end
  end
end

def maybe?
  [true, false].sample
end

def random_quote(md_file)
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
  puts %x(#{cmd}) unless dry
end

def task_add!(tag, quote, due, dry)
  run! "task add due:#{due} +#{tag.capitalize} '#{quote.gsub("'", '"')}'", dry
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
  options = {
    quotes_dir: "#{ENV['HOME']}/Notes/HabitsAndQuotes",
    notes_dirs: "#{ENV['HOME']}/Notes,#{ENV['HOME']}/git/worktime",
    dry_run: false
  }

  opt_parser = OptionParser.new do |opts|
    opts.banner = 'Usage: ruby habits.rb [options]'

    opts.on('-d', '--quotes-dir DIR', 'The quotes directory') do |value|
      options[:quotes_dir] = value
    end

    opts.on('-n', '--notes-dirs DIR1,DIR2,...', 'The notes directories') do |value|
      options[:notes_dirs] = value
    end

    opts.on('-D', '--dry-run', 'Dry run mode') do
      options[:dry_run] = true
    end

    opts.on_tail('-h', '--help', 'Show this help message and exit') do
      puts opts
      exit
    end
  end

  opt_parser.parse!(ARGV)

  notes(options[:notes_dirs].split(','), options[:dry_run]) do |tag, note, due|
    task_add!(tag, note, due, options[:dry_run])
  end

  Dir["#{options[:quotes_dir]}/*.md"].each do |md_file|
    next unless maybe?

    random_quote(md_file) do |tag, quote, due|
      task_add!(tag, quote, due, options[:dry_run])
    end
  end

  unscheduled_tasks do |id|
    task_schedule!(id, "#{rand(0..DEFAULT_TIMESPAN_D)}d", options[:dry_run])
  end
end
