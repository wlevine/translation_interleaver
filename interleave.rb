#!/usr/bin/env ruby

require 'yaml'
require 'optparse'
require 'pragmatic_segmenter'

#remove punctuation from the edges of words
def strip_punctuation(word)
  word.gsub(/^[¿¡"'“‘«(\[]+|[?!.,"'”’»)\]:;]+$/,'')
end

#returns an array of the words contained in string sentence
def collect_words(sentence)
  words = sentence.split(/ |--|—/) #split on spaces, double-dashes, and em-dashes
  #remove non-internal punctuation
  words = words.map do |word|
    strip_punctuation(word)
  end
  words.delete('') #remove empty strings
  words
end

#diagnostic to make sure words are being separated properly
#text is an array of sentences
def print_words(text)
  text.each do |sentence|
    puts collect_words(sentence)
  end
end

#compute number of words shared between two arrays
def num_shared_words(words_a,words_b)
  matches = 0
  words_a.each do |word_a|
    words_b.each_with_index do |word_b,i|
      if (word_a.downcase == word_b.downcase)
        matches += 1
        words_b.delete_at(i)
        break
      end
    end
  end
  matches
end

#similarity between two arrays of words
def similarity_score(words_a,words_b)
  return 0 if words_a.size == 0 || words_b.size == 0
  size = [words_a.size,words_b.size].max
  matches = num_shared_words(words_a,words_b)
  matches.to_f/size
end

def construct_comparandum(array,start_index,num_sentences)
  words = []
  array[start_index,num_sentences].each do |sentence|
    words += collect_words(sentence)
  end
  words
end

def merge_sentences(array,start_index,num_sentences)
  merged = ""
  array[start_index,num_sentences].each do |sentence|
    merged += "#{sentence} "
  end
  merged
end

def check_score(best_score,best_num1,best_num2,try_num1,try_num2,text1,index1,text2,index2)
  score = similarity_score(construct_comparandum(text1,index1,try_num1),construct_comparandum(text2,index2,try_num2))

  if score > best_score
    best_score = score
    best_num1 = try_num1
    best_num2 = try_num2
  end
  [best_score,best_num1,best_num2]
end

def correlate_texts(source,mt,translation)
  index_s = 0 #s for source
  index_t = 0 #t for target
  min_words = 10
  max_extra_sentences = 5
  results = []  
  #what if things don't end so nicely?
  #after the loop I should append the remainder
  while index_s < source.size && index_t < translation.size
    #The idea here is that we will either group EXACTLY one source sentence with 1 <= N <= 5 translation sentences OR we will group EXACTLY one translation sentence with 1 <= N <= 5 source sentences.
    #The exception to this rule is for short sentences. If we have a sentence (or group of sentences) less than 10 words, we will allow it to attach to a larger sentence (before or after), even in cases where normally we would only allow one sentence.

    best_score = 0.0 #running tally of the best score
    best_num_sentences_s = 1 #keep track of the number of setences that gave us the best score
    best_num_sentences_t = 1

    #allow the base number of sentences to vary if the first sentence(s) are short
    num_sentences_to_min_words_s = 1
    num_sentences_to_min_words_t = 1

    while construct_comparandum(mt,index_s,num_sentences_to_min_words_s).size < min_words
      num_sentences_to_min_words_s += 1
    end
    while construct_comparandum(translation,index_t,num_sentences_to_min_words_t).size < min_words
      num_sentences_to_min_words_t += 1
    end

    1.upto(num_sentences_to_min_words_s) do |base_num_sentences_s|
      1.upto(num_sentences_to_min_words_t) do |base_num_sentences_t|
        #get the score comparing just the base sentences
        best_score,best_num_sentences_s,best_num_sentences_t = check_score(best_score,best_num_sentences_s,best_num_sentences_t,base_num_sentences_s,base_num_sentences_t,mt,index_s,translation,index_t)

        1.upto(max_extra_sentences) do |i|
          #Test grouping base source sentence with next i source sentences
          #If permissible, also try grouping base translation sentence with extra sentences
          extra_s = i
          extra_t = 0
          while (index_s+base_num_sentences_s+extra_s <= source.size && index_t+base_num_sentences_t+extra_t <= translation.size)
            best_score,best_num_sentences_s,best_num_sentences_t = check_score(best_score,best_num_sentences_s,best_num_sentences_t,base_num_sentences_s+extra_s,base_num_sentences_t+extra_t,mt,index_s,translation,index_t)
            break unless (construct_comparandum(translation,index_t+base_num_sentences_t,extra_t+1).size < min_words)
            extra_t += 1
          end

          #Test grouping base translation sentence with next i sentences
          #If permissible, also try grouping base source sentence with extra sentences
          extra_s = 0
          extra_t = i
          while (index_s+base_num_sentences_s+extra_s <= source.size && index_t+base_num_sentences_t+extra_t <= translation.size)
            best_score,best_num_sentences_s,best_num_sentences_t = check_score(best_score,best_num_sentences_s,best_num_sentences_t,base_num_sentences_s+extra_s,base_num_sentences_t+extra_t,mt,index_s,translation,index_t)
            break unless (construct_comparandum(mt,index_s+base_num_sentences_s,extra_s+1).size < min_words)
            extra_s += 1
          end
        end
      end
    end

    results << [merge_sentences(source,index_s,best_num_sentences_s),merge_sentences(mt,index_s,best_num_sentences_s), merge_sentences(translation,index_t,best_num_sentences_t)]

    index_s += best_num_sentences_s
    index_t += best_num_sentences_t
  end
  results
end

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: interleave.rb [options]"

  opts.on("-y FILE", "Specify yaml file with source/machine translation pairs") do |file|
    options[:yaml] = file
  end

  opts.on("-m FILE", "Specify human translation text file") do |file|
    options[:translation] = file
  end

  opts.on("-o FILE", "Write output to FILE") do |file|
    options[:output] = file
  end

  opts.on("-t","--target-lang LANG", "two letter code for the target language") do |code|
    options[:target_lang] = code
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

optparse.parse(ARGV)

if !(options[:yaml] && options[:translation] && options[:output] && options[:target_lang])
  puts "Must specify all options!"
  puts optparse
  exit
end

#We will have three texts (arrays of sentences): translation, source, and mt
#First create translation (the human translation text)
translation_text = IO.read(options[:translation])
#add options to use pdf doc_type to ignore line breaks
segmenter = PragmaticSegmenter::Segmenter.new(text: translation_text, language: options[:target_lang])
translation = segmenter.segment

#Now fill source, mt arrays
source = []
mt = []
source_mt_pairs = YAML::load(IO.read(options[:yaml]))
source_mt_pairs.each do |pair|
  source << pair[0]
  mt << pair[1]
end

#diagnostics
#print_words(mt)
#print_words(translation)

results = correlate_texts(source,mt,translation)

results.each do |group|
  puts group[0] #source
  puts group[1] #mt
  puts group[2] #translation
  puts "."
end
