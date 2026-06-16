require_relative 'lib/redmine_slow_query_logger'

Redmine::Plugin.register :redmine_slow_query_logger do
  name 'Redmine Slow Query Logger'
  author 'Codex'
  description 'Logs slow Redmine requests and SQL queries with current user context and readable admin journal.'
  version '0.2.0'
  requires_redmine version_or_higher: '6.0.0'

  settings default: {
    'db_log_enabled' => '1',
    'max_entries' => '1000',
    'slow_sql_ms' => '500',
    'slow_request_ms' => '1000',
    'max_sql_length' => '4000',
    'mask_url_params' => '1',
    'mask_sql_literals' => '0'
  }, partial: 'settings/redmine_slow_query_logger'
end

Redmine::MenuManager.map :admin_menu do |menu|
  menu.push :redmine_slow_query_logger,
            { controller: 'slow_query_logger_entries', action: 'index' },
            caption: 'Slow query log',
            html: { class: 'icon icon-warning' }
end
