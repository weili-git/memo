require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: 'mysql2',
  host: 'localhost',
  port: 3306,
  username: 'root',
  password: '994335',
  database: 'memo'
)
