#!/usr/bin/env ruby

NOTES_DIR = "#{ENV['HOME']}/git/foo.zone-content/gemtext/notes"
MIN_PERCENTAGE = 80
MIN_LENGTH = 10

class String
  CLEAN_PATTERN = [ /\d\d\d-\d\d-\d\d/, /[^A-Za-z0-9!.;,?'" ]/, /\S+\.gmi/, /^\./, /^\d/ ]
  def clean
    CLEAN_PATTERN.each {|p| gsub! p, '' }
    strip
  end
  def letter_percentage?(threshold) = threshold <= (100 * count("A-Za-z")) / length  
end

begin
  puts File.read(Dir["#{NOTES_DIR}/*.gmi"].sample)
           .split("\n")
           .map(&:clean)
           .select{ |l| l.length >= MIN_LENGTH }
           .reject{ |l| l.match?(/Published at/) }
           .select{ |l| l.letter_percentage?(MIN_PERCENTAGE) }
           .sample
end
