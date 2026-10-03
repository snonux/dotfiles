#!/usr/bin/env ruby
# frozen_string_literal: true
# Unit and negative checks for scripts/brokenlinkfinder URL joining (task h33).

require 'uri'

SCRIPT = File.expand_path('../brokenlinkfinder', __dir__)

def fail!(msg)
  warn "brokenlinkfinder test: #{msg}"
  exit 1
end

# Load helpers without executing main ($PROGRAM_NAME != this file).
load SCRIPT

# --- Negative / repro: naive concatenation joins onto the page path -----------
base = 'https://example.com/page/sub'
href = '/foo'
buggy = "#{base}#{href}"
want = 'https://example.com/foo'
fail! "repro setup wrong: buggy=#{buggy}" unless buggy == 'https://example.com/page/sub/foo'
fail! "repro: URI.join must differ from concat" unless URI.join(base, href).to_s == want
fail! "repro: concat must NOT equal correct root-relative target" if buggy == want

# --- Positive: resolve_url matches URI.join for root- and relative-relative ---
cases = {
  '/foo' => 'https://example.com/foo',
  './foo' => 'https://example.com/page/foo',
  'https://example.com/bar' => 'https://example.com/bar',
  '../x' => 'https://example.com/x'
}
cases.each do |link, expected|
  got = resolve_url(base, link)
  fail! "resolve_url(#{link.inspect}) => #{got.inspect}, want #{expected.inspect}" unless got == expected
end

# Trailing-slash base keeps last segment for relative hrefs.
base_dir = 'https://example.com/page/sub/'
got = resolve_url(base_dir, 'foo')
want_dir = 'https://example.com/page/sub/foo'
fail! "resolve_url under dir base => #{got.inspect}, want #{want_dir.inspect}" unless got == want_dir

# --- Negative: invalid hrefs must not raise; resolve returns nil --------------
[' ', 'http://[', "\n", '::'].each do |bad|
  begin
    got = resolve_url(base, bad)
  rescue StandardError => e
    fail! "resolve_url(#{bad.inspect}) raised #{e.class}: #{e.message}"
  end
  fail! "resolve_url(#{bad.inspect}) => #{got.inspect}, want nil" unless got.nil?
end

# --- internal_link?: path forms and same-host; invalid hrefs stay false ------
domain = 'example.com'
['/a', './b', 'https://example.com/c'].each do |link|
  fail! "internal_link?(#{link.inspect}) should be true" unless internal_link?(link, domain)
end
fail! 'external host should not be internal' if internal_link?('https://evil.example/x', domain)
[' ', 'http://[', '::'].each do |bad|
  begin
    got = internal_link?(bad, domain)
  rescue StandardError => e
    fail! "internal_link?(#{bad.inspect}) raised #{e.class}: #{e.message}"
  end
  fail! "internal_link?(#{bad.inspect}) => #{got.inspect}, want false" unless got == false
end

# Structural guard: script must use URI.join (not page+href concatenation).
source = File.read(SCRIPT)
fail! 'script no longer calls URI.join' unless source.include?('URI.join')
fail! 'script still concatenates url+link for root-relative hrefs' if source =~ /\#\{url\}\#\{link\}/

puts 'brokenlinkfinder test: ok'
