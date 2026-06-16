# frozen_string_literal: true

class AddSourceToSlowQueryLoggerEntries < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:slow_query_logger_entries, :source)
      add_column :slow_query_logger_entries, :source, :string
    end

    add_index :slow_query_logger_entries, :source unless index_exists?(:slow_query_logger_entries, :source)
  end
end
