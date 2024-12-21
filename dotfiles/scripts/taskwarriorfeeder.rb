#!/usr/bin/env ruby

require 'optparse'
require 'digest'
require 'set'

PERSONAL_TIMESPAN_D = 30
WORK_TIMESPAN_D = 14
WORKTIME_DIR = "#{ENV['HOME']}/git/worktime".freeze
GOS_DIR = "#{ENV['HOME']}/Notes/GosDir".freeze
MAX_PENDING_RANDOM_TASKS = 14

def maybe?
  [true, false, false].sample
end

def run_from_personal_device?
  `uname`.chomp == 'Linux'
end

def can_have_random?
  `task status:pending +random count`.to_i < MAX_PENDING_RANDOM_TASKS
end

def notes(notes_dirs, prefix, dry)
  notes_dirs.each do |notes_dir|
    Dir["#{notes_dir}/#{prefix}-*"].each do |notes_file|
      match = File.read(notes_file).strip.match(/(?<due>\d+)? *(?<tag>[A-Z]?[a-z,-:]+) *(?<body>.*)/m)
      next unless match

      tags = match[:tag].downcase.split(',') + [prefix]
      tags << 'track' if tags.include?('tr') # tr is shorthand for track

      due = if match[:due].nil?
              tags.include?('track') ? 'eow' : "#{rand(0..PERSONAL_TIMESPAN_D)}d"
            else
              "#{match[:due]}d"
            end
      yield tags, match[:body], due
      File.delete(notes_file) unless dry
    end
  end
end

def random_quote(md_file)
  tag = File.basename(md_file, '.md').downcase
  lines = File.readlines(md_file)

  match = lines.first.match(/\((\d+)\)/)
  timespan = run_from_personal_device? ? PERSONAL_TIMESPAN_D : WORK_TIMESPAN_D
  timespan = match ? match[1].to_i : timespan

  quote = lines.select { |l| l.start_with? '*' }.map { |l| l.sub(/\* +/, '') }.sample
  yield [tag, 'random'], quote.chomp, "#{rand(0..timespan)}d"
end

def run!(cmd, dry)
  puts cmd
  puts `#{cmd}` unless dry
end

def skill_add!(skills_str, dry)
  skills = {}
  skills_file = "#{WORKTIME_DIR}/skills.txt"
  skills_str.split(',').map(&:strip).each { |skill| skills[skill.to_s.downcase] = skill }

  File.foreach(skills_file) do |line|
    line.chomp!
    skills[line.downcase] = line
  end
  File.open("#{skills_file}.tmp", 'w') do |file|
    skills.each_value { |skill| file.puts(skill) }
  end
  return if dry

  File.rename("#{skills_file}.tmp", skills_file)
end

def worklog_add!(tag, quote, due, dry)
  file = "#{WORKTIME_DIR}/wl-#{Time.now.to_i}n.txt"
  content = "#{due.chomp 'd'} #{tag} #{quote}"

  puts "#{file}: #{content}"
  File.write(file, content) unless dry
end

# Queue to Gos https://codeberg.org/snonux/gos
def gos_queue!(tags, message, dry)
  share_tag = []
  platforms = { 'li' => :linkedin, 'ma' => :mastodon, 'x' => :xcom }
  platforms.each do |short, long|
    share_tag << long if tags.include?(short) || tags.include?(long.to_s)
    share_tag << "-#{long}" if tags.include?("-#{short}") || tags.include?("-#{long}")
  end
  share_tag = share_tag.empty? ? '' : ".share:#{share_tag.join(':')}"

  # All tags other than the share tag
  other_tags = tags.reject do |t|
    t.start_with?('-') ||
      t == 'share' ||
      platforms.keys.include?(t.downcase) ||
      platforms.values.include?(t.downcase.to_sym)
  end

  file = "#{GOS_DIR}/#{Digest::MD5.hexdigest(message)}.#{other_tags.join('.')}#{share_tag}.txt"
  puts "Writing #{file}"
  File.write(file, message) unless dry
end

def task_add!(tags, quote, due, dry)
  run! "task add due:#{due} +#{tags.join(' +')} '#{quote.gsub("'", '"')}'", dry
end

def task_schedule!(id, due, dry)
  run! "task modify #{id} due:#{due}", dry
end

def unscheduled_tasks
  lines = `task due:`.split("\n").drop(1)
  lines.pop
  lines.map { |line| line.split.first }.each do |id|
    yield id if id.to_i.positive?
  end
end

begin
  opts = {
    quotes_dir: "#{ENV['HOME']}/Notes/HabitsAndQuotes",
    notes_dirs: "#{ENV['HOME']}/Notes,#{ENV['HOME']}/Notes/Quicklogger,#{ENV['HOME']}/git/worktime",
    dry_run: false,
    no_random: false
  }

  opt_parser = OptionParser.new do |o|
    o.banner = 'Usage: ruby taskwarriorfeeder.rb [options]'
    o.on('-d', '--quotes-dir DIR', 'The quotes directory') { |v| opts[:quotes_dir] = v }
    o.on('-n', '--notes-dirs DIR1,DIR2,...', 'The notes directories') { |v| opts[:notes_dirs] = v }
    o.on('-D', '--dry-run', 'Dry run mode') { opts[:dry_run] = true }
    o.on('-R', '--no-randoms', 'No random entries') { opts[:no_random] = true }
    o.on_tail('-h', '--help', 'Show this help message and exit') { puts o and exit }
  end

  opt_parser.parse!(ARGV)

  (run_from_personal_device? ? %w[ql pl] : %w[wl]).each do |prefix|
    notes(opts[:notes_dirs].split(','), prefix, opts[:dry_run]) do |tags, note, due|
      if tags.include?('skill') || tags.include?('skills')
        skill_add!(note, opts[:dry_run])
      elsif tags.include? 'work'
        worklog_add!(:log, note, due, opts[:dry_run])
      elsif tags.include? 'share'
        gos_queue!(tags, note, opts[:dry_run])
      else
        task_add!(tags, note, due, opts[:dry_run])
      end
    end
  end

  if !opts[:no_random] && can_have_random?
    Dir["#{opts[:quotes_dir]}/*.md"].each do |md_file|
      next unless maybe?

      random_quote(md_file) do |tags, quote, due|
        task_add!(tags, quote, due, opts[:dry_run])
      end
    end
  end

  unscheduled_tasks do |id|
    task_schedule!(id, "#{rand(0..PERSONAL_TIMESPAN_D)}d", opts[:dry_run])
  end
end
