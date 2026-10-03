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
  '../x' => 'https://example.com/x',
  'foo' => 'https://example.com/page/foo',
  'bar/baz' => 'https://example.com/page/bar/baz',
  '//example.com/proto' => 'https://example.com/proto'
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

# Protocol-relative external host resolves but is not same-host.
evil = resolve_url(base, '//evil.com/path')
fail! "resolve //evil => #{evil.inspect}" unless evil == 'https://evil.com/path'

# Non-http(s) schemes must not resolve as checkable URLs.
['mailto:x@y.com', 'javascript:void(0)', 'ftp://example.com/x'].each do |bad|
  got = resolve_url(base, bad)
  fail! "resolve_url(#{bad.inspect}) => #{got.inspect}, want nil" unless got.nil?
end

# Malformed mailto: raises URI::InvalidComponentError (URI::Error, not InvalidURIError).
malformed_mailto = %w[mailto:x mailto: mailto:not-an-email mailto:a@b@c]
malformed_mailto.each do |bad|
  begin
    got = resolve_url(base, bad)
  rescue StandardError => e
    fail! "resolve_url(#{bad.inspect}) raised #{e.class}: #{e.message}"
  end
  fail! "resolve_url(#{bad.inspect}) => #{got.inspect}, want nil" unless got.nil?
end

# --- Negative: invalid hrefs must not raise; resolve returns nil --------------
[' ', 'http://[', "\n", '::'].each do |bad|
  begin
    got = resolve_url(base, bad)
  rescue StandardError => e
    fail! "resolve_url(#{bad.inspect}) raised #{e.class}: #{e.message}"
  end
  fail! "resolve_url(#{bad.inspect}) => #{got.inspect}, want nil" unless got.nil?
end

# --- internal_link?: resolve-then-host; //evil external; bare/../ internal ---
domain = 'example.com'
[
  '/a',
  './b',
  'https://example.com/c',
  'https://EXAMPLE.COM/case',
  '//example.com/same',
  '//EXAMPLE.COM/case-proto',
  'foo',
  'bar/baz',
  '../x'
].each do |link|
  fail! "internal_link?(#{link.inspect}) should be true" unless internal_link?(link, domain, base)
end

[
  '//evil.com/path',
  'https://evil.example/x',
  'http://other.example/y',
  'mailto:x@y.com'
].each do |link|
  fail! "internal_link?(#{link.inspect}) should be false" if internal_link?(link, domain, base)
end

([' ', 'http://[', '::'] + malformed_mailto).each do |bad|
  begin
    got = internal_link?(bad, domain, base)
  rescue StandardError => e
    fail! "internal_link?(#{bad.inspect}) raised #{e.class}: #{e.message}"
  end
  fail! "internal_link?(#{bad.inspect}) => #{got.inspect}, want false" unless got == false
end

# Host compare is case-insensitive both ways.
fail! 'domain case: EXAMPLE.COM should match' unless same_http_host?('https://example.com/z', 'EXAMPLE.COM')
fail! 'host case: Example.Com should match' unless same_http_host?('https://Example.Com/z', 'example.com')

# --- urls_to_check: selected resolved internals are exactly what get checked --
hrefs = [
  '/foo',
  'bar/baz',
  '../x',
  '//evil.com/path',
  'https://evil.example/x',
  '//example.com/proto',
  'https://EXAMPLE.COM/case',
  'mailto:x@y.com',
  ' ',
  '/foo' # duplicate href
]
selected = urls_to_check(base, domain, hrefs)
want_selected = [
  'https://example.com/foo',
  'https://example.com/page/bar/baz',
  'https://example.com/x',
  'https://example.com/proto',
  'https://EXAMPLE.COM/case'
]
fail! "urls_to_check => #{selected.inspect}, want #{want_selected.inspect}" unless selected == want_selected

# Malformed mailto must not raise in urls_to_check; /foo still selected when mixed in.
mixed_bad_mailto = malformed_mailto + ['/foo', 'mailto:x@y.com']
begin
  mixed_selected = urls_to_check(base, domain, mixed_bad_mailto)
rescue StandardError => e
  fail! "urls_to_check with malformed mailto raised #{e.class}: #{e.message}"
end
fail! "mixed mailto scan must still include /foo" unless mixed_selected == ['https://example.com/foo']

# Every selected URL must be internal; nothing external slips through.
selected.each do |u|
  fail! "selected #{u.inspect} failed same_http_host?" unless same_http_host?(u, domain)
end
%w[https://evil.com/path https://evil.example/x].each do |ext|
  fail! "external #{ext} must not be selected" if selected.include?(ext)
end

# Structural guard: script must use URI.join (not page+href concatenation).
source = File.read(SCRIPT)
fail! 'script no longer calls URI.join' unless source.include?('URI.join')
fail! 'script still concatenates url+link for root-relative hrefs' if source =~ /\#\{url\}\#\{link\}/
fail! 'script still uses prefix heuristic for internal_link?' if source =~ /start_with\?\('\/'\)/

puts 'brokenlinkfinder test: ok'
