# spec/word_book_spec.rb
require "rspec"
require_relative "word_book"
require_relative "db/model"

RSpec.describe WordBook do
  before(:each) do
    @word_book = WordBook.new
    # 增加单元测试逻辑
    Word.find_by(word: "test_word").destroy if Word.find_by(word: "test_word")
  end

  after(:each) do
    # 清除单元测试数据
    Word.find_by(word: "test_word").destroy if Word.find_by(word: "test_word")
  end

  describe "#create" do
    it "测试创建单词" do
      @word_book.handle("create test_word test_meaning")
      expect(Word.find_by(word: "test_word").meaning).to eq("test_meaning")
    end

    it "测试创建单词时，单词已存在" do
      @word_book.handle("create test_word test_meaning")
      expect { @word_book.handle("create test_word test_meaning") }.to output("word test_word already exists\n").to_stdout
    end

    it "测试创建单词时，参数不完整" do
      @word_book.handle("create test_word")
      expect { @word_book.handle("create test_word") }.to output("Usage: create WORD MEANING - Create a new word with its meaning\n").to_stdout
    end
  end

  describe "#find" do
    it "测试查找单词" do
      @word_book.handle("create test_word test_meaning")
      expect { @word_book.handle("find test_word") }.to output("test_word - test_meaning - 1 day - 0\n").to_stdout
    end

    it "测试查找单词时，单词不存在" do
      expect { @word_book.handle("find test_word") }.to output("No result.\n").to_stdout
    end

    it "测试查找单词时，参数不完整" do
      expect { @word_book.handle("find") }.to output("Usage: find KEYWORD - Search word by keyword\n").to_stdout
    end
  end

  describe "#delete" do
    it "测试删除单词" do
      @word_book.handle("create test_word test_meaning")
      @word_book.handle("delete test_word")
      expect(Word.find_by(word: "test_word").deleted).to eq(true)
    end

    it "测试删除单词时，单词不存在" do
      expect { @word_book.handle("delete test_word") }.to output("word test_word doesn't exist or have been deleted\n").to_stdout
    end

    it "测试删除单词时，参数不完整" do
      expect { @word_book.handle("delete") }.to output("Usage: delete WORD - Set WORD deteletd to true\n").to_stdout
    end
  end

  describe "#update" do
    it "测试更新单词" do
      @word_book.handle("create test_word test_meaning")
      @word_book.handle("update test_word new_test_meaning")
      expect(Word.find_by(word: "test_word").meaning).to eq("new_test_meaning")
    end

    it "测试更新单词时，单词不存在" do
      expect { @word_book.handle("update test_word new_test_meaning") }.to output("word test_word doesn't exist or have been deleted\n").to_stdout
    end

    it "测试更新单词时，参数不完整" do
      expect { @word_book.handle("update test_word") }.to output("Usage: update WORD NEW_MEANING - Update the meaning of a word\n").to_stdout
    end
  end

  describe "#list" do
    it "测试列出单词" do
      @word_book.handle("create test_word test_meaning")
      expect { @word_book.handle("list 1") }.to output("test_word - test_meaning - 1 day - 0\n").to_stdout
    end
  end

  describe "#undo" do
    it "测试撤销操作" do
      @word_book.handle("create test_word test_meaning")
      @word_book.handle("undo")
      expect(Word.find_by(word: "test_word")).to eq(nil)
    end

    it "测试撤销操作时，操作记录为空" do
      expect { @word_book.handle("undo") }.to output("No operation to undo.\n").to_stdout
    end
  end

  describe "#help" do
    it "测试帮助信息" do
      for cmd in WordBook::USAGE_DICT.keys
        expect { @word_book.handle("help #{cmd}") }.to output(WordBook::USAGE_DICT[cmd].chomp + "\n").to_stdout
      end
    end
  end
end
