#!/usr/bin/env ruby
# frozen_string_literal: true
# Checks for scripts/randomnote.rb String#clean (task lg4): URLs and .gmi
# links must be removed, not mashed into text by the character filter.
# The end-to-end part runs the script with HOME pointed at a temporary
# directory of sample notes, never at the real notes directory.

require 'open3'
require 'tmpdir'
require 'fileutils'

SCRIPT = File.expand_path('../randomnote.rb', __dir__)

def fail!(msg)
  warn "randomnote test: #{msg}"
  exit 1
end

# Loading must not run main ($PROGRAM_NAME != the script).
load SCRIPT

cases = {
  'See https://foo.zone/gemfeed/x.html for more' => 'See for more',
  'Old http://example.org/a?b=c link' => 'Old link',
  'Read 2024-01-01-some-post.gmi today' => 'Read today',
  'Read ./gemfeed/index.gmi today' => 'Read today',
  # Negative: plain prose passes through, only disallowed characters dropped.
  'Plain sentence, no links: here!' => 'Plain sentence, no links here!',
  'Mind the gap; really?' => 'Mind the gap; really?'
}
cases.each do |input, want|
  got = input.dup.clean
  fail! "clean(#{input.inspect}) => #{got.inspect}, want #{want.inspect}" unless got == want
end

# Negative: no URL fragments survive in mashed form.
mashed = 'Visit https://foo.zone/x.html now'.dup.clean
fail! "URL left mashed text: #{mashed.inspect}" if mashed.include?('foo.zone') || mashed.include?('https')

# End to end: a note made only of URL lines plus one prose line must print
# the prose line, and never a URL remnant.
Dir.mktmpdir do |home|
  notes = File.join(home, 'git/foo.zone-content/gemtext/notes')
  FileUtils.mkdir_p(notes)
  book = File.join(home, 'Buecher/Diverse/Search-Inside-Yourself.txt')
  FileUtils.mkdir_p(File.dirname(book))
  body = "=> https://foo.zone/gemfeed/2024-01-01-very-long-post-name.html\n" \
         "This is a calm sentence about attention and focus\n"
  File.write(File.join(notes, 'sample.gmi'), body)
  File.write(book, body)
  5.times do
    out, err, status = Open3.capture3({ 'HOME' => home }, 'ruby', SCRIPT)
    fail! "script failed: #{err}" unless status.success?
    line = out.strip
    want = 'This is a calm sentence about attention and focus'
    fail! "script printed #{line.inspect}, want #{want.inspect}" unless line == want
  end
end

puts 'randomnote test: ok'
