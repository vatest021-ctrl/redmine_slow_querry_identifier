# frozen_string_literal: true

module RedmineSlowQueryLogger
  class RequestMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      Context.reset!
      request = ActionDispatch::Request.new(env)
      Context.set_request(request)

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      status, headers, response = @app.call(env)
      duration_ms = elapsed_ms(started)

      log_request(duration_ms, status) if duration_ms >= Config.slow_request_ms || Config.log_all_requests?

      [status, headers, response]
    ensure
      Context.clear!
    end

    private

    def elapsed_ms(started)
      (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000.0
    end

    def log_request(duration_ms, status)
      context = Context.current.merge(Context.user_snapshot)
      rounded_duration = duration_ms.round(1)
      sql_duration_ms = context.fetch(:sql_duration_ms, 0.0).round(1)

      Rails.logger.warn(
        '[redmine_slow_query_logger] ' \
        "slow_request duration_ms=#{rounded_duration} " \
        "threshold_ms=#{Config.slow_request_ms} " \
        "status=#{status.inspect} " \
        "user_id=#{context[:user_id].inspect} " \
        "login=#{context[:login].inspect} " \
        "request_id=#{context[:request_id].inspect} " \
        "ip=#{context[:ip].inspect} " \
        "method=#{context[:method].inspect} " \
        "path=#{context[:path].inspect} " \
        "sql_count=#{context.fetch(:sql_count, 0)} " \
        "slow_sql_count=#{context.fetch(:slow_sql_count, 0)} " \
        "sql_duration_ms=#{sql_duration_ms}"
      )

      Store.record!(
        event_type: 'request',
        duration_ms: rounded_duration,
        threshold_ms: Config.slow_request_ms,
        status: status,
        user_id: context[:user_id],
        login: context[:login],
        request_id: context[:request_id],
        ip: context[:ip],
        http_method: context[:method],
        path: context[:path],
        sql_count: context.fetch(:sql_count, 0),
        slow_sql_count: context.fetch(:slow_sql_count, 0),
        sql_duration_ms: sql_duration_ms
      )
    rescue StandardError => e
      Rails.logger.warn("[redmine_slow_query_logger] request logging failed: #{e.class}: #{e.message}")
    end
  end
end
