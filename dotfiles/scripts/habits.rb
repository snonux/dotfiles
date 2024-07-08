#!/usr/bin/env ruby

require 'optparse'

# Gets a random item from the quotes file
class RandomQuote
  def initialize(md_path)
    @md_path = md_path
  end
end

begin
  options = {
    quotes_dir: "#{ENV['HOME']}/Notes/HabitsAndQuotes"
  }

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: ruby habits.rb [options]"

    opts.on('-d', '--quotes-dir DIR', 'The quotes directory') do |name|
      options[:quotes_dir] = name
    end

    # Define any other options as needed
    opts.on_tail('-h', '--help', 'Show this help message and exit') do
      puts opts
      exit
    end
  end

  opt_parser.parse!(ARGV)
end
