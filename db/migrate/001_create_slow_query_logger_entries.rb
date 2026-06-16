# frozen_string_literal: true

class CreateSlowQueryLoggerEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :slow_query_logger_entries do |t|
      t.string :event_type, null: false
      t.float :duration_ms, null: false
      t.integer :threshold_ms
      t.integer :status
      t.integer :user_id
      t.string :login
      t.string :request_id
      t.string :ip
      t.string :source
      t.string :http_method
      t.text :path
      t.string :sql_name
      t.integer :sql_count
      t.integer :slow_sql_count
      t.float :sql_duration_ms
      t.text :sql
      t.boolean :sql_truncated, null: false, default: false
      t.timestamps null: false
    end

    add_index :slow_query_logger_entries, :created_at
    add_index :slow_query_logger_entries, :event_type
    add_index :slow_query_logger_entries, :login
    add_index :slow_query_logger_entries, :user_id
    add_index :slow_query_logger_entries, :request_id
    add_index :slow_query_logger_entries, :ip
    add_index :slow_query_logger_entries, :source
    add_index :slow_query_logger_entries, :duration_ms
  end
end
