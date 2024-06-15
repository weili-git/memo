# encoding: UTF-8

require "time"

class WordBook
  WORDS_FILE = "words.txt"
  BIN_FILE = "bin.txt"
  IMPT_FILE = "impt.txt"
  DELIMITER = "|"
  SHORT_TERM_REVIEW_THRESHOLD = 24 * 60 * 60  # 24 hours in seconds

  USAGE_DICT = {
    "new" => "Usage: new WORD MEANING - Add a new word with its meaning",
    "remove" => "Usage: remove WORD - Remove a word to bin",
    "update" => "Usage: update WORD NEW_MEANING - Update the meaning of a word and remove the old one to bin",
    "mark" => "Usage: mark WORD - Mark a word as important",
    "review" => "Usage: review WORD|-f list - increase reviews for given word or last listed ones",
    "list" => <<-EOF,
Usage: list [OPTIONS]
  Options:
    N|-a   - Number of words / All of the words
    -r     - Random order
    -v     - List review words
    -f     - From bin, words or impt
  EOF
    "undo" => "Usage: undo - Undo last command",
    "redo" => "Usage: redo - Redo last undo command",
    "help" => "Usage: help [COMMAND] - Show help for commands",
    "quit" => "Usage: quit - Exit the program",
  }

  def initialize
    @words = load_words(WORDS_FILE)
    @bin_words = load_words(BIN_FILE)
    @impt_words = load_words(IMPT_FILE)
    @history = []
    @redo_history = []
    @last_listed_words = []
  end

  def handle(input)
    command, *args = input.split(" ")
    options = parse_list_args(args)
    send(command.downcase, options)
  end

  def method_missing(name, args)
    puts "Unknown command #{name} - #{args}. Type 'help' for a list of commands."
  end

  def parse_list_args(args)
    options = {
      word: nil,
      meaning: nil,

      count: nil,
      all: false,

      random: false,
      review: false,

      from: nil,
      cancel: false,
    }

    i = 0
    while i < args.length
      arg = args[i]
      case arg
      when "-r"
        options[:random] = true
      when "-v"
        options[:review] = true
      when "-rv" # short
        options[:random] = true
        options[:review] = true
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
    move_and_log("new", nil, @words, options)
  end

  def remove(options)
    move_and_log("remove", @words, @bin_words, options)
  end

  def update(options)
    if !(options[:word] && options[:meaning])
      puts USAGE_DICT["update"]
      return
    end

    if options[:cancel] # undo new meaning
      @words.delete(options[:word])
    end
    # if !options[:cancel] && !@bin_words[options[:word]].nil? # overwrite, cannot undo!
    #   @bin_words.delete(options[:word])
    # end
    # update 旧数据丢入bin
    # bin 如果已存在将会覆盖，并且无法用undo复原！
    move_and_log("update", @words, @bin_words, options)
    if !options[:cancel] # new meaning
      @words[options[:word]] = { meaning: options[:meaning], timestamp: Time.now }
    end
  end

  def list(options)
    if options[:count].nil? ^ options[:all]
      puts USAGE_DICT["list"]
      return
    end
    words = case options[:from]
      when nil
        @words
      when "bin"
        @bin_words
      when "impt"
        @impt_words
      else
        raise "Unknown file path: #{options[:from]}"
      end
    words = words.filter {
      |k, v|
      get_days_until_review(v) <= 0 && (Time.now - v[:last_review]) > SHORT_TERM_REVIEW_THRESHOLD
    } if options[:review]
    if options[:random]
      words = words.to_a.sample(options[:count])
    else
      words = words.sort_by { |k, v| -v[:timestamp].to_i }
      words = words.first(options[:count]) if options[:count]
    end
    @last_listed_words = words.map { |k| k[0] }
    display_words(words)
  end

  def mark(options)
    move_and_log("mark", @words, @impt_words, options)
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
    last_command = @history.pop
    @redo_history.push({
      command: last_command[:command].dup,
      options: last_command[:options].dup,
    })
    last_command[:options][:cancel] = !last_command[:options][:cancel]
    send(last_command[:command], last_command[:options])
    @history.pop if @history.last == last_command # remove duplicate history
  end

  def redo(options)
    return if @redo_history.empty?
    last_undo = @redo_history.pop
    send(last_undo[:command], last_undo[:options])
  end

  def review(options)
    if !options[:word].nil? ^ options[:from].nil?
      puts USAGE_DICT["review"]
      return
    end
    if options[:from].nil?
      words = [options[:word]]
    elsif options[:from] == "list"
      words = @last_listed_words
    else
      puts "Unkown argument: -f #{options[:from]}"
      return
    end
    words.each do |word|
      if @words.key?(word)
        @words[word][:review] += options[:cancel] ? -1 : 1
        @words[word][:review] = @words[word][:review] < 0 ? 0 : @words[word][:review]
        @words[word][:last_review] = Time.now
        puts "Reviewed: #{word}, total reviews: #{@words[word][:review]}"
      else
        puts "Word not found: #{word}"
      end
    end
    file_do(:overwrite, WORDS_FILE)
    @history.push({ command: "review", options: options.dup })
  end

  private

  def move_and_log(command, from, to, options)
    if !options[:word]
      USAGE_DICT[command]
      return
    end

    word = options[:word]
    action, from, to = options[:cancel] ? ["Restored", to, from] : ["Applied", from, to]
    if move(from, to, options)
      if options[:cancel] && to.nil? # add -c
        puts "#{action} #{command}: #{word} - #{options[:meaning]}"
      else
        puts "#{action} #{command}: #{word} - #{to[word][:meaning]}"
      end
    end
    @history.push({ command: command, options: options.dup })
  end

  def move(from, to, options)
    word = options[:word]
    if !from.nil? && !from.key?(word)
      puts "Word not found in #{from == @words ? "words" : from == @bin_words ? "bin" : "important"}: #{word}"
      return false
    end
    if !to.nil? && to.key?(word)
      puts "Word #{word} already exists in #{to == @words ? "words" : to == @bin_words ? "bin" : "important"} with meaning #{to[word][:meaning]}"
      return false
    end

    if !(from.nil? || to.nil?) # remove, mark, update
      to[word] = from[word]
      from.delete(word)
    elsif from.nil? # new
      if options[:meaning].nil?
        puts USAGE_DICT["new"]
        return false
      end
      to[word] = { meaning: options[:meaning], timestamp: Time.now, last_review: Time.now, review: 0 }
    elsif to.nil? # new -c
      from.delete(word)
    else
      puts "Tried to move from nil to nil"
      return false
    end
    file_do(:push, to == @words ? WORDS_FILE : to == @bin_words ? BIN_FILE : IMPT_FILE, word) if !to.nil?
    file_do(:overwrite, from == @words ? WORDS_FILE : from == @bin_words ? BIN_FILE : IMPT_FILE) if !from.nil?
    return true
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
        file.puts([word, words[word][:meaning], words[word][:timestamp], words[word][:last_review], words[word][:review]].join(DELIMITER))
      end
    when :overwrite
      File.open(file_path, "w:UTF-8") do |file|
        words.each do |k, v|
          file.puts([k, v[:meaning], v[:timestamp], v[:last_review], v[:review]].join(DELIMITER))
        end
      end
    end
  end

  def load_words(file_path)
    return {} unless File.exist?(file_path)
    dict = {}
    File.open(file_path, "r:UTF-8") do |file|
      file.each_line do |line|
        word, meaning, timestamp, last_review, review = line.chomp.split(DELIMITER)
        dict[word] = { meaning: meaning, timestamp: Time.parse(timestamp), last_review: Time.parse(last_review), review: review.to_i }
      end
    end
    dict
  end

  def display_words(words)
    max_len = words.map { |k| k[0].length }.max
    words.each do |k, v|
      padding = "  " * [0, max_len - k.length].max
      days_until_review = get_days_until_review(v)
      days_until_review = days_until_review < 0 ? 0 : days_until_review
      days_text = days_until_review <= 1 ? "day" : "days"
      puts "#{k}#{padding} - #{v[:meaning]} - #{days_until_review} #{days_text}"
    end
  end

  def get_days_until_review(v)
    return (2 ** v[:review]) - ((Time.now - v[:timestamp]) / 86400).to_i
  end
end
