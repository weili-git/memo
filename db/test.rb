require_relative 'db_config'
require_relative 'model'

File.open('../words.txt', 'r').each_line do |line|

  data = line.strip.split('|')

  word = Word.create(
    word: data[0],
    meaning: data[1],
    created_at: data[2],  # 假设第三个字段是创建时间
    last_reviewed_at: data[3],  # 假设第四个字段是上次复习时间
    review_count: data[4],  # 假设第五个字段是复习次数
    deleted: data[5] == '1'  # 假设第六个字段是是否被删除，使用 '1' 表示 TRUE
  )

  if word.persisted?
    puts "Inserted word: #{word.word} with meaning: #{word.meaning}"
  else
    puts "Failed to insert word."
  end

end
