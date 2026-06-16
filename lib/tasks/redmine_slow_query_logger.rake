# frozen_string_literal: true

namespace :redmine_slow_query_logger do
  desc 'Generate database load to verify Redmine Slow Query Logger'
  task db_load: :environment do
    iterations = ENV.fetch('ITERATIONS', '10').to_i
    project_limit = ENV.fetch('PROJECT_LIMIT', '1000').to_i
    user_id = ENV['USER_ID']

    if user_id && defined?(User)
      User.current = User.find_by(id: user_id)
      abort "User with id=#{user_id} not found" unless User.current
    end

    project_ids = Project.order(:id).limit(project_limit).pluck(:id)
    abort 'No projects found. Create projects first or reduce test scope.' if project_ids.empty?

    puts "Running #{iterations} load iterations against #{project_ids.size} projects"
    puts "Current user: #{User.current&.login || 'anonymous'}" if defined?(User)
    puts 'Tip: set REDMINE_SLOW_SQL_LOG_ALL=1 or REDMINE_SLOW_SQL_MS=0 to force SQL log output.'

    iterations.times do |index|
      count = Issue.
        joins(:project, :status).
        where(projects: { id: project_ids }).
        where('projects.status IN (?)', [Project::STATUS_ACTIVE, Project::STATUS_ARCHIVED]).
        where(
          "EXISTS (
            SELECT 1
            FROM enabled_modules em
            WHERE em.project_id = projects.id AND em.name = 'issue_tracking'
          )"
        ).
        count

      puts "iteration=#{index + 1} issues_count=#{count}"
    end
  end
end
