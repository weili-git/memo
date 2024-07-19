# encoding: UTF-8

require "time"
require_relative "db/db_config"
require_relative "db/model"

class WordBook
  USAGE_DICT = {
    "create" => "Usage: create WORD MEANING - Create a new word with its meaning",
    "find" => "Usage: find KEYWORD - Search word by keyword",
    "delete" => "Usage: delete WORD - Set WORD deteletd to true",
    "update" => "Usage: update WORD NEW_MEANING - Update the meaning of a word",
    "review" => "Usage: review WORD|-f list - increase reviews for given word or last listed ones",
    "list" => <<-EOF,
Usage: list [OPTIONS]
  Options:
    N      - Number of words
    -r     - Random order
    -v     - List review words
  EOF
    "undo" => "Usage: undo - undo last operation",
    "help" => "Usage: help [COMMAND] - Show help for commands",
    "quit" => "Usage: quit - Exit the program",
  }

  def initialize()
    @history = []
    @last_listed_words = nil
  end

  def handle(input)
    command, *args = input.split(" ")
    command = command.downcase
    if !USAGE_DICT.key?(command)
      puts "Command #{command} not found."
      return
    end
    options = {
      command: command,
      word: nil,
      meaning: nil,
      count: nil,
      random: false,
      review: false,
    }

    i = 0
    while i < args.length
      arg = args[i]
      case arg
      when "-r"
        options[:random] = true
      when "-v"
        options[:review] = true
      when "-rv" # shortcut
        options[:random] = true
        options[:review] = true
      when "-f"
        options[:from] = args[i + 1] if args[i + 1]
        i += 1
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
    return if !is_valid(options)
    send(command, options)
  end

  def find(options)
    keyword = options[:word]
    words = Word.where("word LIKE ? OR meaning LIKE ?", "%#{keyword}%", "%#{keyword}%")
    if words.empty?
      puts "No result."
    else
      display_words(words)
    end
  end

  def create(options)
    word, meaning = options[:word], options[:meaning]
    new_word = Word.new(word: word, meaning: meaning)
    if new_word.save
      puts "word created: #{word} - #{meaning}"
      @history << options
    else
      puts "word #{word} already exists"
    end
  end

  def delete(options)
    word = options[:word]
    word_record = Word.find_by(word: word, deleted: false)
    if word_record
      word_record.update(deleted: true)
      puts "word deleted: #{word}"
      @history << options
    else
      puts "word #{word} doesn't exist or have been deleted"
    end
  end

  def update(options)
    word = options[:word]
    new_meaning = options[:meaning]

    word_record = Word.find_by(word: word, deleted: false)
    old_meaning = word_record.meaning
    word_record.meaning = new_meaning
    if word_record.save
      puts "word updated: #{word.word}"
      options[:meaning] = old_meaning
      @history << options
    else
      puts "word #{word} doesn't exist or have been deleted"
    end
  end

  def list(options)
    words = Word.where(deleted: false)
    words = words.where("DATEDIFF(NOW(), created_at) > POW(2, review_count)") if options[:review]
    words = words.order(options[:random] ? "RAND()" : "created_at DESC")
    words = words.limit(options[:count]) if options[:count]
    @last_listed_words = words
    display_words(words)
  end

  def review(options)
    if options[:word] == "list"
      words = @last_listed_words
      options[:meaning] = @last_listed_words
    else
      word = Word.find_by(word: options[:word], deleted: false)
      words = word ? [word] : []
    end

    words.each do |word|
      word.increment(:review_count)
      if word.save
        puts "reviewed #{word.word}"
      else
        puts "word #{word.word} not found"
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

  def undo(options)
    return if @history.empty?
    last_opt = @history.pop
    case last_opt[:command]
    when "create"
      word_to_undo = Word.find_by(word: last_opt[:word], meaning: last_opt[:meaning], deleted: false)
      if word_to_undo
        word_to_undo.destroy
        puts "Undone creation of '#{word_to_undo.word}'."
      end
    when "delete"
      word_to_undo = Word.find_by(word: last_opt[:word], deleted: true)
      word_to_undo.deleted = false
      if word_to_undo.save
        puts "Undone deletion of '#{word_to_undo.word}'."
      end
    when "update"
      word_to_undo = Word.find_by(word: last_opt[:word], deleted: false)
      word_to_undo.meaning = last_opt[:meaning]
      if word_to_undo.save
        puts "Undone update of '#{word_to_undo.word}'."
      end
    when "review"
      if last_opt[:word] != "list"
        word_to_undo = Word.find_by(word: last_opt[:word], deleted: false)
        word_to_undo.decrement(review_count)
        word_to_undo.save
      else
        last_opt[:meaning].each do |word|
          word.decrement(review_count)
          word.save
        end
      end
      puts "Undone review"
    end
  end

  private

  def is_valid(options)
    cmd = options[:command]
    case cmd
    when "create", "update"
      return true if options[:word] && options[:meaning]
    when "delete", "find", "review"
      return true if options[:word]
    else # "list", "quit"
      return true
    end
    puts USAGE_DICT[cmd]
    return false
  end

  def display_words(words)
    return if words.nil? || words.empty?

    max_len = words.map { |line| line.word.length }.max
    words.each do |line|
      padding = "  " * [0, max_len - line.word.length].max
      days_until_review = get_days_until_review(line)
      days_until_review = days_until_review < 0 ? 0 : days_until_review
      days_text = days_until_review <= 1 ? "day" : "days"
      puts "#{line.word}#{padding} - #{line.meaning} - #{days_until_review} #{days_text} - #{line.review_count}"
    end
  end

  def get_days_until_review(v)
    return (2 ** v.review_count) - ((Time.now - v.created_at) / 86400).to_i
  end
end
