# spec/word_book_spec.rb
require "rspec"
require_relative "word_book"

RSpec.describe WordBook do
  before(:each) do
    # 创建临时文件用于测试
    @words_file = "spec/words_test.txt"
    @bin_file = "spec/bin_test.txt"
    @impt_file = "spec/impt_test.txt"
    File.write(@words_file, "hello|world|#{Time.now.iso8601}\nhi|there|#{Time.now.iso8601}\n")
    File.write(@bin_file, "")
    File.write(@impt_file, "")

    # 创建 WordBook 实例
    @word_book = WordBook.new

    # 重写类常量用于测试
    WordBook.send(:remove_const, :WORDS_FILE)
    WordBook.const_set(:WORDS_FILE, @words_file)
    WordBook.send(:remove_const, :BIN_FILE)
    WordBook.const_set(:BIN_FILE, @bin_file)
    WordBook.send(:remove_const, :IMPT_FILE)
    WordBook.const_set(:IMPT_FILE, @impt_file)

    # 重新加载文件
    @word_book = WordBook.new
  end

  after(:each) do
    # 删除测试文件
    File.delete(@words_file) if File.exist?(@words_file)
    File.delete(@bin_file) if File.exist?(@bin_file)
    File.delete(@impt_file) if File.exist?(@impt_file)
  end

  describe "#new" do
    it "adds a new word with its meaning" do
      options = { word: "goodbye", meaning: "farewell" }
      expect { @word_book.new(options) }.to output("Applied new: goodbye - farewell\n").to_stdout
      expect(@word_book.instance_variable_get(:@words).keys).to include("goodbye")
    end

    it "does not add a word if it already exists" do
      options = { word: "hello", meaning: "greeting" }
      expect { @word_book.new(options) }.to output("Word hello already exists in words with meaning world\n").to_stdout
    end
  end

  describe "#remove" do
    it "removes a word and moves it to the bin" do
      options = { word: "hello" }
      expect { @word_book.remove(options) }.to output("Applied remove: hello - world\n").to_stdout
      expect(@word_book.instance_variable_get(:@words).keys).not_to include("hello")
      expect(@word_book.instance_variable_get(:@bin_words).keys).to include("hello")
    end

    it "restores a word from the bin" do
      options = { word: "hello" }
      @word_book.remove(options)
      restore_options = { word: "hello", cancel: true }
      expect { @word_book.remove(restore_options) }.to output("Restored remove: hello - world\n").to_stdout
      expect(@word_book.instance_variable_get(:@words).keys).to include("hello")
      expect(@word_book.instance_variable_get(:@bin_words).keys).not_to include("hello")
    end
  end

  describe "#update" do
    it "updates the meaning of a word and moves the old one to the bin" do
      options = { word: "hello", meaning: "greeting" }
      expect { @word_book.update(options) }.to output("Applied update: hello - world\n").to_stdout # print old meaning - move_and_log()
      expect(@word_book.instance_variable_get(:@words)["hello"][:meaning]).to eq("greeting")
      expect(@word_book.instance_variable_get(:@bin_words).keys).to include("hello")
    end
  end

  describe "#mark" do
    it "marks a word as important" do
      options = { word: "hello" }
      expect { @word_book.mark(options) }.to output("Applied mark: hello - world\n").to_stdout
      expect(@word_book.instance_variable_get(:@impt_words).keys).to include("hello")
      expect(@word_book.instance_variable_get(:@words).keys).not_to include("hello")
    end

    it "unmarks a word as important" do
      options = { word: "hello" }
      @word_book.mark(options)
      unmark_options = { word: "hello", cancel: true }
      expect { @word_book.mark(unmark_options) }.to output("Restored mark: hello - world\n").to_stdout
      expect(@word_book.instance_variable_get(:@impt_words).keys).not_to include("hello")
      expect(@word_book.instance_variable_get(:@words).keys).to include("hello")
    end
  end

  describe "#list" do
    it "lists all words if -a option is given" do
      options = { all: true }
      expect { @word_book.list(options) }.to output(/hi\s+- there - 1 day\nhello\s+- world - 1 day\n/).to_stdout # 注意顺序
    end

    it "lists a specified number of words" do
      options = { count: 1 }
      expect { @word_book.list(options) }.to output(/hi\s+- there - 1 day\n/).to_stdout
    end
  end

  describe "#undo" do
    it "undo a add coomand" do
      options = { word: "goodbye", meaning: "farewell" }
      expect { @word_book.new(options) }.to output("Applied new: goodbye - farewell\n").to_stdout
      expect { @word_book.undo(nil) }.to output("Restored new: goodbye - farewell\n").to_stdout
      expect { @word_book.redo(nil) }.to output("Applied new: goodbye - farewell\n").to_stdout
    end
  end
end
