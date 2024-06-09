# encoding: UTF-8

require "time"

class WordBook
  WORDS_FILE = "words.txt"
  BIN_FILE = "bin.txt"
  IMPT_FILE = "impt.txt"
  DELIMITER = "|"
  USAGE_DICT = {
    "new" => "Usage: new WORD MEANING - Add a new word with its meaning",
    "remove" => "Usage: remove WORD - Remove a word to bin",
    "update" => "Usage: update WORD NEW_MEANING - Update the meaning of a word and remove the old one to bin",
    "mark" => "Usage: mark WORD - Mark a word as important",
    "list" => <<-EOF,
Usage: list [OPTIONS]
  Options:
    N|-a   - Number of words / All of the words
    -r     - Random order
    -f     - From bin, word or impt
  EOF
    "help" => "Usage: help [COMMAND] - Show help for commands",
    "quit" => "Usage: quit - Exit the program",
  }

  def initialize
    @words = load_words(WORDS_FILE)
    @bin_words = load_words(BIN_FILE)
    @impt_words = load_words(IMPT_FILE)
  end

  def load_words(file_path)
    return {} unless File.exist?(file_path)
    dict = {}
    File.open(file_path, "r:UTF-8") do |file|
      file.each_line do |line|
        word, meaning, timestamp = line.chomp.split(DELIMITER)
        dict[word] = { meaning: meaning, timestamp: Time.parse(timestamp) }
      end
    end
    dict
  end

  def method_missing(name, args)
    puts "Unknown command #{name} - #{args}. Type 'help' for a list of commands."
  end

  def parse_list_args(args)
    options = {
      word: nil,
      meaning: nil,
      count: nil,
      random: false,
      all: false,
      from: "word",
      cancel: false,
    }

    i = 0
    while i < args.length
      arg = args[i]
      case arg
      when "-r"
        options[:random] = true
      when "-a"
        options[:all] = true
      when "-f"
        options[:from] = args[i + 1] if args[i + 1]
        i += 1
      when "-c"
        options[:cancel] = true
      else
        if arg =~ /^\d+$/
          options[:count] = arg.to_i if options[:count].nil?
        else
          options[:word] = arg
          options[:meaning] = args[i + 1..-1].join(" ") if args[i + 1]
          break
        end
      end
      i += 1
    end

    return options
  end

  def new(options)
    if !(options[:word] && options[:meaning])
      puts USAGE_DICT["new"]
      return
    end
    word = options[:word]
    if @words.key?(word)
      puts "Word #{word} already exists with meaning: #{@words[word][:meaning]}"
    else
      @words[word] = { meaning: options[:meaning], timestamp: Time.now }
      file_do(:push, WORDS_FILE, word)
      puts "Added: #{word} - #{options[:meaning]}"
    end
  end

  def remove(options)
    if !options[:word]
      puts USAGE_DICT["remove"]
      return
    end
    word = options[:word]
    if options[:cancel]
      if move(word, @bin_words, @words)
        puts "Restored: #{word} - #{@words[word][:meaning]}"
      end
    else
      if move(word, @words, @bin_words)
        puts "Removed: #{word} - #{@bin_words[word][:meaning]}"
      end
    end
  end

  def update(options)
    if !(options[:word] && options[:meaning])
      puts USAGE_DICT["update"]
      return
    end
    word = options[:word]
    if move(word, @words, @bin_words)
      @words[word] = { meaning: options[:meaning], timestamp: Time.now }
      puts "Updated: #{word} - #{options[:meaning]}"
    end
  end

  def list(options)
    if options[:count].nil? ^ options[:all]
      puts USAGE_DICT["list"]
      return
    end
    words = case options[:from]
      when "word"
        @words
      when "bin"
        @bin_words
      when "impt"
        @impt_words
      else
        raise "Unknown file path: #{options[:from]}"
      end
    if options[:random]
      words = words.to_a.sample(options[:count])
    else
      words = words.sort_by { |k, v| -v[:timestamp].to_i } # not :count for :all
      if options[:count]
        words = words.first(options[:count])
      end
    end
    display_words(words)
  end

  def mark(options)
    if !options[:word]
      puts USAGE_DICT["mark"]
      return
    end
    word = options[:word]
    if options[:cancel]
      if move(word, @impt_words, @words)
        puts "Unmarked #{word} as important."
      end
    else
      if move(word, @words, @impt_words)
        puts "Marked #{word} as important."
      end
    end
  end

  def help(options)
    if options[:word].nil?
      USAGE_DICT.each_value do |usage|
        puts usage
      end
    else
      usage = USAGE_DICT[options[:word]]
      puts usage.nil? ? "No help available for #{options[:word]}" : usage
    end
  end

  def quit(options)
    puts "Exiting the program..."
    exit
  end

  private

  def move(word, from, to)
    if from.key?(word)
      to[word] = from[word]
      from.delete(word)
      file_do(:push, to == @words ? WORDS_FILE : to == @bin_words ? BIN_FILE : IMPT_FILE, word)
      file_do(:overwrite, from == @words ? WORDS_FILE : from == @bin_words ? BIN_FILE : IMPT_FILE)
      return true
    else
      puts "Word not found in #{from == @words ? "words" : from == @bin_words ? "bin" : "important"}: #{word}"
      return false
    end
  end

  def file_do(operation, file_path, word = nil)
    words = case file_path
      when WORDS_FILE
        @words
      when BIN_FILE
        @bin_words
      when IMPT_FILE
        @impt_words
      else
        raise "Unknown file path: #{file_path}"
      end

    case operation
    when :push
      File.open(file_path, "a:UTF-8") do |file|
        file.puts([word, words[word][:meaning], words[word][:timestamp]].join(DELIMITER))
      end
    when :overwrite
      File.open(file_path, "w:UTF-8") do |file|
        words.each do |k, v|
          file.puts([k, v[:meaning], v[:timestamp]].join(DELIMITER))
        end
      end
    end
  end

  def display_words(words)
    max_len = words.map{ |k| k[0].length }.max
    words.each do |k, v|
      padding = "  " * [0, max_len - k.length].max
      puts "#{k}#{padding} - #{v[:meaning]}"
    end
  end
end
