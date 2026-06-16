# frozen_string_literal: true

require_relative 'redmine_slow_query_logger/config'
require_relative 'redmine_slow_query_logger/context'
require_relative 'redmine_slow_query_logger/source_classifier'
require_relative 'redmine_slow_query_logger/sanitizer'
require_relative 'redmine_slow_query_logger/store'
require_relative 'redmine_slow_query_logger/sql_subscriber'
require_relative 'redmine_slow_query_logger/controller_subscriber'

Rails.application.config.after_initialize do
  RedmineSlowQueryLogger::Config.refresh!
  RedmineSlowQueryLogger::SqlSubscriber.install!
  RedmineSlowQueryLogger::ControllerSubscriber.install!
end
