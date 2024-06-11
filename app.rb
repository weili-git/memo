# encoding: UTF-8

require "readline"
require_relative "word_book"

wb = WordBook.new

while true
  input = Readline.readline(">> ", true).force_encoding("UTF-8")
  wb.handle(input)
end
