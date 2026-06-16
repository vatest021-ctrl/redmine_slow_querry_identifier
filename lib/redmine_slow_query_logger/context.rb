# frozen_string_literal: true

module RedmineSlowQueryLogger
  module Context
    THREAD_KEY = :redmine_slow_query_logger_context

    module_function

    def current
      Thread.current[THREAD_KEY] ||= {}
    end

    def reset!
      Thread.current[THREAD_KEY] = {
        sql_count: 0,
        sql_duration_ms: 0.0,
        slow_sql_count: 0
      }
    end

    def clear!
      Thread.current[THREAD_KEY] = nil
    end

    def add_sql(duration_ms, slow:)
      context = current
      context[:sql_count] = context.fetch(:sql_count, 0) + 1
      context[:sql_duration_ms] = context.fetch(:sql_duration_ms, 0.0) + duration_ms
      context[:slow_sql_count] = context.fetch(:slow_sql_count, 0) + 1 if slow
    end

    def set_request(request)
      context = current
      context[:request_id] = request.request_id
      context[:ip] = request.remote_ip
      context[:method] = request.request_method
      context[:path] = Sanitizer.mask_url(request.fullpath)
    end

    def set_controller_payload(payload)
      context = current
      headers = payload[:headers]
      request = headers.respond_to?(:[]) ? headers['action_dispatch.request'] : nil

      context[:request_id] ||= request&.request_id || headers_value(headers, 'action_dispatch.request_id')
      context[:ip] ||= request&.remote_ip || headers_value(headers, 'action_dispatch.remote_ip')
      context[:method] ||= payload[:method] || request&.request_method
      context[:path] ||= Sanitizer.mask_url(payload[:path] || request&.fullpath)
      context[:format] ||= payload[:format] || request&.format&.symbol
      context[:controller] ||= payload[:controller]
      context[:source] = SourceClassifier.classify(
        path: context[:path],
        format: context[:format],
        controller: context[:controller],
        login: user_snapshot[:login]
      )
    end

    def user_snapshot
      return anonymous_user unless defined?(User)

      user = User.current
      return anonymous_user if user.nil? || (user.respond_to?(:anonymous?) && user.anonymous?)

      {
        user_id: user.id,
        login: user.login
      }
    rescue StandardError
      anonymous_user
    end

    def anonymous_user
      {
        user_id: nil,
        login: 'anonymous'
      }
    end

    def headers_value(headers, key)
      return nil unless headers.respond_to?(:[])

      headers[key]
    rescue StandardError
      nil
    end
  end
end
