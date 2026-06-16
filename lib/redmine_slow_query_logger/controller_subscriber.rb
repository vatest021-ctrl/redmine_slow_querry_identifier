# frozen_string_literal: true

module RedmineSlowQueryLogger
  module ControllerSubscriber
    module_function

    def install!
      return if @installed

      # Используем Rails notifications вместо middleware: в Redmine/Rails 7
      # middleware stack может быть уже заморожен во время загрузки плагинов.
      ActiveSupport::Notifications.subscribe('start_processing.action_controller') do |_name, _started, _finished, _id, payload|
        start_request(payload)
      end

      ActiveSupport::Notifications.subscribe('process_action.action_controller') do |_name, started, finished, _id, payload|
        finish_request(started, finished, payload)
      end

      @installed = true
    end

    def start_request(payload)
      # Контекст хранится в текущем потоке, чтобы SQL-события внутри этого
      # web/API-запроса получили тот же request_id, пользователя, IP и source.
      Context.reset!
      Context.set_controller_payload(payload)
    rescue StandardError => e
      Rails.logger.warn("[redmine_slow_query_logger] request context setup failed: #{e.class}: #{e.message}")
    end

    def finish_request(started, finished, payload)
      Context.set_controller_payload(payload)
      duration_ms = (finished - started) * 1000.0

      # Request-событие пишем только если весь HTTP-запрос превысил порог.
      return unless duration_ms >= Config.slow_request_ms || Config.log_all_requests?

      log_request(duration_ms, payload)
    rescue StandardError => e
      Rails.logger.warn("[redmine_slow_query_logger] request logging failed: #{e.class}: #{e.message}")
    ensure
      Context.clear!
    end

    def log_request(duration_ms, payload)
      context = Context.current.merge(Context.user_snapshot)
      rounded_duration = duration_ms.round(1)
      sql_duration_ms = context.fetch(:sql_duration_ms, 0.0).round(1)
      status = payload[:status]

      Rails.logger.warn(
        '[redmine_slow_query_logger] ' \
        "slow_request duration_ms=#{rounded_duration} " \
        "threshold_ms=#{Config.slow_request_ms} " \
        "status=#{status.inspect} " \
        "user_id=#{context[:user_id].inspect} " \
        "login=#{context[:login].inspect} " \
        "request_id=#{context[:request_id].inspect} " \
        "ip=#{context[:ip].inspect} " \
        "source=#{context[:source].inspect} " \
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
        source: context[:source],
        http_method: context[:method],
        path: context[:path],
        sql_count: context.fetch(:sql_count, 0),
        slow_sql_count: context.fetch(:slow_sql_count, 0),
        sql_duration_ms: sql_duration_ms
      )
    end
  end
end
