# frozen_string_literal: true

get 'slow_query_logger_entries', to: 'slow_query_logger_entries#index'
delete 'slow_query_logger_entries', to: 'slow_query_logger_entries#destroy_all'
