# frozen_string_literal: true

class AddSqlTruncatedToSlowQueryLoggerEntries < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:slow_query_logger_entries, :sql_truncated)
      add_column :slow_query_logger_entries, :sql_truncated, :boolean, null: false, default: false
    end
  end
end
