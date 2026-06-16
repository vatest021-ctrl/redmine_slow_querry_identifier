# frozen_string_literal: true

require_relative 'redmine_slow_query_logger/config'
require_relative 'redmine_slow_query_logger/context'
require_relative 'redmine_slow_query_logger/sanitizer'
require_relative 'redmine_slow_query_logger/store'
require_relative 'redmine_slow_query_logger/sql_subscriber'
require_relative 'redmine_slow_query_logger/request_middleware'

Rails.application.config.after_initialize do
  RedmineSlowQueryLogger::SqlSubscriber.install!
end

Rails.application.config.middleware.use RedmineSlowQueryLogger::RequestMiddleware
