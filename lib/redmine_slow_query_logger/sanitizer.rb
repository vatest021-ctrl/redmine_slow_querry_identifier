# frozen_string_literal: true

module RedmineSlowQueryLogger
  module Sanitizer
    SENSITIVE_PARAM = /(password|passwd|pwd|token|key|secret|auth|session|cookie)/i

    module_function

    def mask_url(path)
      return path unless Config.mask_url_params?
      return path if path.nil? || !path.include?('?')

      raw_path, query = path.split('?', 2)
      masked_query = query.to_s.split('&').map do |pair|
        key, value = pair.split('=', 2)
        next key.to_s if value.nil?

        masked_value = key.to_s.match?(SENSITIVE_PARAM) ? '[FILTERED]' : value
        "#{key}=#{masked_value}"
      end.join('&')

      "#{raw_path}?#{masked_query}"
    rescue StandardError
      path
    end

    def mask_sql(sql)
      return sql unless Config.mask_sql_literals?

      sql.to_s.
        gsub(/'(?:''|[^'])*'/, "'?'").
        gsub(/\b\d+\b/, '?')
    end
  end
end
