require 'minitest/autorun'
require_relative 'word_book'

class TestWordBook < MiniTest::Test
  def setup
    @word_book = WordBook.new
  end

  def test_load_words
    assert_equal({}, @word_book.load_words("non_existing_file.txt"))
    # 创建一个临时文件并写入数据，用于测试 load_words 方法的行为
    File.write("temp_file.txt", "test|This is a test|2024-01-01\n")
    expected_result = { "test" => { meaning: "This is a test", timestamp: Time.parse("2024-01-01") } }
    assert_equal(expected_result, @word_book.load_words("temp_file.txt"))
    File.delete("temp_file.txt")
  end

  def test_new_word
    @word_book.new({ word: 'test', meaning: 'This is a test' })
    assert @word_book.instance_variable_get(:@words).key?('test')
  end

end

TestWordBook.new