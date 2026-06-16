# frozen_string_literal: true

module RedmineSlowQueryLogger
  module Config
    module_function

    def slow_sql_ms
      integer_env('REDMINE_SLOW_SQL_MS', setting_value('slow_sql_ms', '500').to_i)
    end

    def slow_request_ms
      integer_env('REDMINE_SLOW_REQUEST_MS', setting_value('slow_request_ms', '1000').to_i)
    end

    def max_sql_length
      integer_env('REDMINE_SLOW_SQL_MAX_LENGTH', setting_value('max_sql_length', '4000').to_i)
    end

    def db_log_enabled?
      setting_value('db_log_enabled', '1') == '1'
    end

    def max_entries
      integer_env('REDMINE_SLOW_LOG_MAX_ENTRIES', setting_value('max_entries', '1000').to_i)
    end

    def log_all_sql?
      truthy_env?('REDMINE_SLOW_SQL_LOG_ALL')
    end

    def log_all_requests?
      truthy_env?('REDMINE_SLOW_REQUEST_LOG_ALL')
    end

    def mask_url_params?
      setting_value('mask_url_params', '1') == '1'
    end

    def mask_sql_literals?
      setting_value('mask_sql_literals', '0') == '1'
    end

    def integer_env(name, default)
      value = ENV[name]
      return default if value.nil? || value.empty?

      Integer(value)
    rescue ArgumentError
      default
    end

    def truthy_env?(name)
      %w[1 true yes on].include?(ENV.fetch(name, '').downcase)
    end

    def setting_value(key, default)
      return default unless defined?(Setting)

      Setting.plugin_redmine_slow_query_logger.fetch(key, default).to_s
    rescue StandardError
      default
    end
  end
end
