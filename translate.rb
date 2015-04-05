#!/usr/bin/env ruby

require 'optparse'
require 'yaml'
require 'pragmatic_segmenter'
require 'bing_translator'

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: translate.rb [options]"

  opts.on("-i","--input FILE", "Use FILE as source text") do |file|
    options[:source] = file
  end

  opts.on("-o","--output FILE", "Write source/mt pairs to FILE") do |file|
    options[:output] = file
  end

  opts.on("-s","--source-lang LANG", "two letter code for the source language") do |code|
    options[:source_lang] = code
  end

  opts.on("-t","--target-lang LANG", "two letter code for the target language") do |code|
    options[:target_lang] = code
  end

  opts.on("-c","--client-id ID", "bing translator client ID") do |id|
    options[:client_id] = id
  end

  opts.on("-k","--client-secret SECRET", "bing translator client secret") do |secret|
    options[:secret] = secret
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

optparse.parse(ARGV)

if !(options[:source] && options[:output] && options[:source_lang] && options[:target_lang] && options[:client_id] && options[:secret])
  puts "Must specify all options!"
  puts optparse
  exit
end

source_lang = options[:source_lang]
target_lang = options[:target_lang]

translator = BingTranslator.new(options[:client_id], options[:secret])

source = IO.read(options[:source])

#using pdf doc_type shouldn't be mandatory
segmenter = PragmaticSegmenter::Segmenter.new(text: source, language: source_lang, doc_type: 'pdf')
source_segments = segmenter.segment

puts "Checking translation of first sentence:"
puts source_segments[0]
puts translator.translate(source_segments[0], :from => source_lang, :to => target_lang)
puts "Translating all..."

source_mt_pairs = source_segments.map do |source_sentence|
  mt_sentence = translator.translate(source_sentence, :from => source_lang, :to => target_lang)
  [String.new(source_sentence), String.new(mt_sentence)] #need to convert these to pure Strings to get them to serialize properly
end

File.open(options[:output],'w') do |file|
  file.puts YAML::dump(source_mt_pairs)
end
