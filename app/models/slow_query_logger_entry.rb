# frozen_string_literal: true

class SlowQueryLoggerEntry < ActiveRecord::Base
  self.table_name = 'slow_query_logger_entries'

  validates :event_type, inclusion: { in: %w[sql request] }

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :since, ->(time) { where(arel_table[:created_at].gteq(time)) }
  scope :until_time, ->(time) { where(arel_table[:created_at].lteq(time)) }
end
