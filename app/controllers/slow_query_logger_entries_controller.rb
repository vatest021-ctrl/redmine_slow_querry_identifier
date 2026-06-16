# frozen_string_literal: true

class SlowQueryLoggerEntriesController < ApplicationController
  layout 'admin'

  before_action :require_admin

  def index
    @event_type = params[:event_type].to_s
    @source = params[:source].to_s
    @login = params[:login].to_s.strip
    @ip = params[:ip].to_s.strip
    @request_id = params[:request_id].to_s.strip
    @min_duration_ms = params[:min_duration_ms].to_s.strip
    @from = params[:from].to_s.strip
    @to = params[:to].to_s.strip

    @entries = SlowQueryLoggerEntry.recent
    @entries = @entries.where(event_type: @event_type) if %w[sql request].include?(@event_type)
    @entries = @entries.where(source: @source) if sources.include?(@source)
    @entries = @entries.where('login LIKE ?', "%#{@login}%") if @login.present?
    @entries = @entries.where('ip LIKE ?', "%#{@ip}%") if @ip.present?
    @entries = @entries.where(request_id: @request_id) if @request_id.present?
    @entries = @entries.where('duration_ms >= ?', @min_duration_ms.to_f) if positive_number?(@min_duration_ms)
    @entries = @entries.since(parsed_time(@from)) if parsed_time(@from)
    @entries = @entries.until_time(parsed_time(@to)) if parsed_time(@to)
    @entry_count = @entries.count
    @entries = @entries.limit(limit)
  end

  def destroy_all
    SlowQueryLoggerEntry.delete_all
    flash[:notice] = 'Slow query log cleared.'
    redirect_to action: 'index'
  end

  private

  def sources
    %w[portal api export feed webhook plugin_endpoint public unknown]
  end

  def limit
    value = params.fetch(:limit, 100).to_i
    value.clamp(10, 1000)
  end

  def parsed_time(value)
    return nil if value.blank?

    Time.zone.parse(value)
  rescue ArgumentError, TypeError
    nil
  end

  def positive_number?(value)
    value.present? && value.to_f.positive?
  end
end
