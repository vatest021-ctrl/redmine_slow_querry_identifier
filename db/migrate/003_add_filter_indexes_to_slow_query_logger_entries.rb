# frozen_string_literal: true

class AddFilterIndexesToSlowQueryLoggerEntries < ActiveRecord::Migration[7.2]
  def change
    add_index :slow_query_logger_entries, :request_id unless index_exists?(:slow_query_logger_entries, :request_id)
    add_index :slow_query_logger_entries, :ip unless index_exists?(:slow_query_logger_entries, :ip)
    add_index :slow_query_logger_entries, :duration_ms unless index_exists?(:slow_query_logger_entries, :duration_ms)
  end
end
