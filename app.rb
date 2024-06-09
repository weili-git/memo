# encoding: UTF-8

require "readline"
require_relative "word_book"

wb = WordBook.new

while true
  input = Readline.readline(">> ", true).force_encoding("UTF-8")
  command, *args = input.split(" ")
  options = wb.parse_list_args(args)
  wb.public_send(command.downcase, options)
end
