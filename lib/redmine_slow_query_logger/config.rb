# frozen_string_literal: true

module RedmineSlowQueryLogger
  module Config
    DEFAULTS = {
      'db_log_enabled' => '1',
      'max_entries' => '1000',
      'slow_sql_ms' => '500',
      'slow_request_ms' => '1000',
      'max_sql_length' => '4000',
      'mask_url_params' => '1',
      'mask_sql_literals' => '0'
    }.freeze

    module_function

    def refresh!
      @settings = load_settings
    end

    def slow_sql_ms
      integer_env('REDMINE_SLOW_SQL_MS', setting_value('slow_sql_ms').to_i)
    end

    def slow_request_ms
      integer_env('REDMINE_SLOW_REQUEST_MS', setting_value('slow_request_ms').to_i)
    end

    def max_sql_length
      integer_env('REDMINE_SLOW_SQL_MAX_LENGTH', setting_value('max_sql_length').to_i)
    end

    def db_log_enabled?
      setting_value('db_log_enabled') == '1'
    end

    def max_entries
      integer_env('REDMINE_SLOW_LOG_MAX_ENTRIES', setting_value('max_entries').to_i)
    end

    def log_all_sql?
      truthy_env?('REDMINE_SLOW_SQL_LOG_ALL')
    end

    def log_all_requests?
      truthy_env?('REDMINE_SLOW_REQUEST_LOG_ALL')
    end

    def mask_url_params?
      setting_value('mask_url_params') == '1'
    end

    def mask_sql_literals?
      setting_value('mask_sql_literals') == '1'
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

    def setting_value(key)
      (@settings || DEFAULTS).fetch(key, DEFAULTS.fetch(key))
    end

    def load_settings
      return DEFAULTS.dup unless defined?(Setting)
      return DEFAULTS.dup if defined?(Store) && Store.writing?

      DEFAULTS.merge(Setting.plugin_redmine_slow_query_logger.to_h.transform_values(&:to_s))
    rescue StandardError
      DEFAULTS.dup
    end
  end
end
