# frozen_string_literal: true

module RedmineSlowQueryLogger
  module SourceClassifier
    API_EXTENSIONS = %w[.json .xml].freeze
    EXPORT_EXTENSIONS = %w[.csv .pdf .xlsx .xls].freeze
    FEED_EXTENSIONS = %w[.atom .rss].freeze
    WEBHOOK_PATTERN = %r{/(hook|hooks|webhook|webhooks)(/|$)}i

    module_function

    def classify(path:, format: nil, controller: nil, login: nil)
      # Классификация эвристическая: она нужна для быстрого расследования
      # источника нагрузки, а не для строгого security-аудита.
      normalized_path = path.to_s.split('?', 2).first
      normalized_format = format.to_s.downcase

      return 'api' if API_EXTENSIONS.any? { |extension| normalized_path.end_with?(extension) }
      return 'api' if %w[json xml].include?(normalized_format)

      return 'export' if EXPORT_EXTENSIONS.any? { |extension| normalized_path.end_with?(extension) }
      return 'export' if %w[csv pdf xlsx xls].include?(normalized_format)

      return 'feed' if FEED_EXTENSIONS.any? { |extension| normalized_path.end_with?(extension) }
      return 'feed' if %w[atom rss].include?(normalized_format)

      return 'webhook' if normalized_path.match?(WEBHOOK_PATTERN)
      return 'plugin_endpoint' if plugin_controller?(controller)
      return 'public' if login.to_s == 'anonymous'
      return 'portal' if normalized_path.present?

      'unknown'
    end

    def plugin_controller?(controller)
      controller_name = controller.to_s
      return false if controller_name.blank?

      # Все неизвестные контроллеры считаем endpoints плагинов. Список core
      # контроллеров Redmine можно расширять при обновлении Redmine.
      core_controllers = %w[
        account activities admin attachments auth_sources boards calendars
        comments custom_fields documents enumerations files gantts groups
        imports issue_categories issue_relations issue_statuses issues
        journals mail_handler messages my news projects queries repositories
        roles search settings sys timelog trackers users versions watchers
        welcome wiki wiki_edits workflows
      ]

      !core_controllers.include?(controller_name)
    end
  end
end
