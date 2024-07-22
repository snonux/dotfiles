#!/usr/bin/env ruby

NOTES_DIR = "#{ENV['HOME']}/git/foo.zone-content/gemtext/notes"
BOOK_PATH = "#{ENV['HOME']}/Buecher/Diverse/Search-Inside-Yourself.txt"
MIN_PERCENTAGE = 80
MIN_LENGTH = 10

class String
  CLEAN_PATTERN = [ 
    /\d\d\d-\d\d-\d\d/, /[^A-Za-z0-9!.;,?'" @]/, 
    /http.?:\/\/\S+/, /\S+\.gmi/, /^\./, /^\d/,
  ]
  def clean
    CLEAN_PATTERN.each {|p| gsub! p, '' }
    gsub(/\s+/, ' ').strip
  end
  def letter_percentage?(threshold) = threshold <= (100 * count("A-Za-z")) / length  
end

begin
  srand Random.new_seed
  puts File.read((Dir["#{NOTES_DIR}/*.gmi"] + [BOOK_PATH]).shuffle.sample)
           .split("\n")
           .map(&:clean)
           .select{ |l| l.length >= MIN_LENGTH }
           .reject{ |l| l.match?(/(Published at|EMail your comments)/) }
           .reject{ |l| l.match?(/'|book notes/) }
           .select{ |l| l.letter_percentage?(MIN_PERCENTAGE) }
           .shuffle.sample
end
