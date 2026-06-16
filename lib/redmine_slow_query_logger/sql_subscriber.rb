# frozen_string_literal: true

module RedmineSlowQueryLogger
  module SqlSubscriber
    IGNORED_NAMES = %w[SCHEMA CACHE TRANSACTION].freeze

    module_function

    def install!
      return if @installed

      ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, started, finished, _id, payload|
        handle_sql(started, finished, payload)
      end

      @installed = true
    end

    def handle_sql(started, finished, payload)
      return if Store.writing?
      return if ignored_payload?(payload)

      duration_ms = (finished - started) * 1000.0
      slow = duration_ms >= Config.slow_sql_ms
      Context.add_sql(duration_ms, slow: slow)

      return unless slow || Config.log_all_sql?

      context = Context.current.merge(Context.user_snapshot)
      sql, sql_truncated = sanitize_sql(payload[:sql].to_s)
      rounded_duration = duration_ms.round(1)

      Rails.logger.warn(
        '[redmine_slow_query_logger] ' \
        "slow_sql duration_ms=#{rounded_duration} " \
        "threshold_ms=#{Config.slow_sql_ms} " \
        "user_id=#{context[:user_id].inspect} " \
        "login=#{context[:login].inspect} " \
        "request_id=#{context[:request_id].inspect} " \
        "ip=#{context[:ip].inspect} " \
        "method=#{context[:method].inspect} " \
        "path=#{context[:path].inspect} " \
        "name=#{payload[:name].inspect} " \
        "sql=#{sql.inspect}"
      )

      Store.record!(
        event_type: 'sql',
        duration_ms: rounded_duration,
        threshold_ms: Config.slow_sql_ms,
        user_id: context[:user_id],
        login: context[:login],
        request_id: context[:request_id],
        ip: context[:ip],
        http_method: context[:method],
        path: context[:path],
        sql_name: payload[:name],
        sql: sql,
        sql_truncated: sql_truncated
      )
    rescue StandardError => e
      Rails.logger.warn("[redmine_slow_query_logger] sql logging failed: #{e.class}: #{e.message}")
    end

    def ignored_payload?(payload)
      payload[:cached] || IGNORED_NAMES.include?(payload[:name].to_s)
    end

    def sanitize_sql(sql)
      normalized = Sanitizer.mask_sql(sql).gsub(/\s+/, ' ').strip
      max_length = Config.max_sql_length
      return [normalized, false] if normalized.length <= max_length

      ["#{normalized[0, max_length]}... [truncated]", true]
    end
  end
end
