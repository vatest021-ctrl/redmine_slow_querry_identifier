# frozen_string_literal: true

module RedmineSlowQueryLogger
  module Store
    THREAD_KEY = :redmine_slow_query_logger_writing

    module_function

    def record!(attributes)
      # Флаг включается до любых проверок БД, включая table_exists?.
      # Иначе проверка таблицы может сама породить sql.active_record событие.
      Thread.current[THREAD_KEY] = true
      return unless Config.db_log_enabled?
      return unless available?

      SlowQueryLoggerEntry.create!(attributes.compact)
      prune!
    rescue StandardError => e
      Rails.logger.warn("[redmine_slow_query_logger] journal write failed: #{e.class}: #{e.message}")
    ensure
      Thread.current[THREAD_KEY] = false
    end

    def writing?
      Thread.current[THREAD_KEY] == true
    end

    def available?
      defined?(SlowQueryLoggerEntry) &&
        SlowQueryLoggerEntry.table_exists?
    rescue StandardError
      false
    end

    def prune!
      max_entries = Config.max_entries
      return if max_entries <= 0

      # Удаляем только старые записи сверх лимита, чтобы журнал не рос бесконечно.
      extra_count = SlowQueryLoggerEntry.count - max_entries
      return if extra_count <= 0

      ids = SlowQueryLoggerEntry.order(created_at: :asc).limit(extra_count).pluck(:id)
      SlowQueryLoggerEntry.where(id: ids).delete_all if ids.any?
    end
  end
end
