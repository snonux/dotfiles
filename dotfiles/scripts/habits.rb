#!/usr/bin/env ruby

require 'optparse'

DEFAULT_TIMESPAN_D = 365
AUTO_PREFIX = 'auto'.freeze

def random_quote(md_file)
  return unless [true, false].sample

  category = File.basename(md_file, '.md').downcase
  lines = File.readlines(md_file)

  match = lines.first.match(/\((\d+)\)/)
  timespan = match ? match[1].to_i : DEFAULT_TIMESPAN_D

  quote = lines.select { |l| l.start_with? '*' }
               .map { |l| l.sub(/\* +/, '') }
               .sample

  yield category, quote, "#{rand(0..timespan)}d"
end

def taskwarrior!(category, quote, due)
  cmd = "task add due:#{due} +#{AUTO_PREFIX}_#{category} '#{quote.gsub("'", '"')}'"
  puts cmd
end

begin
  options = {
    quotes_dir: "#{ENV['HOME']}/Notes/HabitsAndQuotes"
  }

  opt_parser = OptionParser.new do |opts|
    opts.banner = 'Usage: ruby habits.rb [options]'

    opts.on('-d', '--quotes-dir DIR', 'The quotes directory') do |name|
      options[:quotes_dir] = name
    end

    opts.on_tail('-h', '--help', 'Show this help message and exit') do
      puts opts
      exit
    end
  end

  opt_parser.parse!(ARGV)

  Dir["#{options[:quotes_dir]}/*.md"].each do |md_file|
    random_quote(md_file) do |category, quote, due| 
      taskwarrior!(category, quote, due)
    end
  end
end
