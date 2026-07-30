require 'fileutils'
require 'json'
require 'net/http'
require 'open-uri'
require 'sqlite3'
require 'sinatra/base'
require 'sinatra/cookies'
require 'time'
require 'uri'

class DevConsoleApp < Sinatra::Base
  helpers Sinatra::Cookies

  PROJECT_PAGES = %w[projects stories logs sentry tests].freeze
  SENTRY_TABS = %w[overview issues releases].freeze
  DEFAULT_PROJECT_NAME = 'מרכז ניהול בדיקות ותיעוד'
  DATABASE_PATH = File.expand_path('db/devconsole.sqlite3', __dir__)
  STORIES_PATH = File.expand_path('documentation/stories.json', __dir__)

  before do
    @theme = cookies['theme'] || 'dark'
  end

  helpers do
    def db
      settings.db
    end

    def projects
      db.execute('SELECT * FROM projects ORDER BY updated_at DESC, id DESC')
    end

    def project_by_id(project_id)
      return nil unless project_id.to_s.match?(/\A\d+\z/)

      db.get_first_row('SELECT * FROM projects WHERE id = ?', project_id.to_i)
    end

    def stories
      db.execute('SELECT * FROM stories ORDER BY position ASC, id ASC')
    end

    def sentry_issues
      db.execute('SELECT * FROM sentry_issues ORDER BY last_seen_at DESC, id DESC')
    end

    def sentry_releases
      db.execute('SELECT * FROM sentry_releases ORDER BY released_at DESC, id DESC')
    end

    def sync_runs
      db.execute('SELECT * FROM sync_runs ORDER BY started_at DESC, id DESC LIMIT 12')
    end

    def stats_for_projects
      all = projects
      linked = all.count { |project| present?(project['github_url']) }
      staged = all.count { |project| present?(project['staging_url']) }
      { total: all.length, linked: linked, staged: staged }
    end

    def stats_for_sentry
      {
        issues: sentry_issues.length,
        critical: sentry_issues.count { |issue| issue['level'] == 'error' || issue['level'] == 'fatal' },
        releases: sentry_releases.length
      }
    end

    def stats_for_stories
      all = stories
      completed = all.count { |story| story['status'] == 'completed' }
      { total: all.length, completed: completed }
    end

    def active_page
      page = params[:page].to_s
      return 'projects' if page.empty?
      return page if PROJECT_PAGES.include?(page)
      'projects'
    end

    def active_sentry_tab
      tab = params[:tab].to_s
      return 'overview' if tab.empty?
      return tab if SENTRY_TABS.include?(tab)
      'overview'
    end

    def page_title
      {
        'projects' => 'פרויקטים',
        'stories' => 'סיפורים',
        'logs' => 'לוגים',
        'sentry' => 'Sentry',
        'tests' => 'בדיקות'
      }[active_page] || 'פרויקטים'
    end

    def format_time(value)
      return 'n/a' if value.nil? || value.to_s.empty?

      Time.parse(value.to_s).localtime.strftime('%Y-%m-%d %H:%M')
    rescue StandardError
      value.to_s
    end

    def present?(value)
      value.to_s.strip != ''
    end

    def project_count_label
      stats = stats_for_projects
      "#{stats[:total]} projects"
    end

    def theme_toggle_label
      @theme == 'dark' ? 'Light' : 'Dark'
    end

    def nav_class(page)
      active_page == page ? 'active' : ''
    end

    def story_acceptance(story)
      JSON.parse(story['acceptance_criteria'] || '[]')
    rescue StandardError
      []
    end

    def story_dependencies(story)
      JSON.parse(story['dependencies'] || '[]')
    rescue StandardError
      []
    end

    def story_labels(story)
      JSON.parse(story['labels'] || '[]')
    rescue StandardError
      []
    end

    def story_steps(story)
      JSON.parse(story['cucumber_steps'] || '[]')
    rescue StandardError
      []
    end

    def sentry_level_class(level)
      case level.to_s
      when 'error', 'fatal' then 'badge--err'
      when 'warn', 'warning' then 'badge--warn'
      when 'info' then 'badge--ok'
      else 'badge--muted'
      end
    end

    def log_level_class(level)
      case level.to_s
      when 'error', 'fatal' then 'level-error'
      when 'warn', 'warning' then 'level-warn'
      when 'info' then 'level-info'
      when 'trace' then 'level-trace'
      else 'level-debug'
      end
    end
  end

  get '/' do
    redirect '/projects'
  end

  get '/:page' do
    pass unless PROJECT_PAGES.include?(params[:page])

    @page = active_page
    @tab = active_sentry_tab
    @projects = projects
    @editing_project = project_by_id(params[:edit_id])
    @stories = stories
    @sentry_issues = sentry_issues
    @sentry_releases = sentry_releases
    @sync_runs = sync_runs
    @project_stats = stats_for_projects
    @story_stats = stats_for_stories
    @sentry_stats = stats_for_sentry
    @log_entries = demo_logs
    erb :index
  end

  get '/sentry/:tab' do
    pass unless SENTRY_TABS.include?(params[:tab])

    @page = 'sentry'
    @tab = active_sentry_tab
    @projects = projects
    @stories = stories
    @sentry_issues = sentry_issues
    @sentry_releases = sentry_releases
    @sync_runs = sync_runs
    @project_stats = stats_for_projects
    @story_stats = stats_for_stories
    @sentry_stats = stats_for_sentry
    @log_entries = demo_logs
    erb :index
  end

  post '/theme' do
    response.set_cookie('theme', value: params[:theme].to_s == 'light' ? 'light' : 'dark', path: '/', max_age: '31536000')
    redirect back
  end

  post '/projects' do
    upsert_project_from_params(params)
    redirect '/projects'
  end

  post '/projects/:id' do
    upsert_project_from_params(params.merge('id' => params[:id]))
    redirect '/projects?edit_id=' + params[:id].to_s
  end

  post '/projects/:id/delete' do
    delete_project(params[:id])
    redirect '/projects'
  end

  post '/sync' do
    refresh_external_sources!(db, reason: 'manual')
    redirect back
  end

  post '/sentry/refresh' do
    seed_sentry_data(db)
    refresh_sentry_from_config!(db)
    redirect '/sentry/issues'
  end

  not_found do
    redirect '/projects'
  end

  def self.initialize_schema(db)
    db.execute_batch <<~SQL
      CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        github_url TEXT NOT NULL DEFAULT '',
        staging_url TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_synced_at TEXT
      );

      CREATE TABLE IF NOT EXISTS stories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        story_key TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        goal TEXT NOT NULL,
        description TEXT NOT NULL,
        solution TEXT NOT NULL,
        acceptance_criteria TEXT NOT NULL,
        cucumber_feature TEXT NOT NULL,
        cucumber_scenario TEXT NOT NULL,
        cucumber_steps TEXT NOT NULL,
        estimate_hours INTEGER NOT NULL,
        actual_hours INTEGER,
        status TEXT NOT NULL,
        github_issue_url TEXT NOT NULL DEFAULT '',
        github_pr_url TEXT NOT NULL DEFAULT '',
        dependencies TEXT NOT NULL DEFAULT '',
        labels TEXT NOT NULL DEFAULT '',
        position INTEGER NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS sentry_issues (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sentry_key TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        level TEXT NOT NULL,
        user TEXT NOT NULL DEFAULT '',
        environment TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'open',
        url TEXT NOT NULL DEFAULT '',
        first_seen_at TEXT,
        last_seen_at TEXT,
        event_count INTEGER NOT NULL DEFAULT 1,
        message TEXT NOT NULL DEFAULT '',
        project_name TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS sentry_releases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        release_key TEXT NOT NULL UNIQUE,
        version TEXT NOT NULL,
        environment TEXT NOT NULL DEFAULT '',
        url TEXT NOT NULL DEFAULT '',
        released_at TEXT,
        commit_count INTEGER NOT NULL DEFAULT 0,
        user_count INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS sync_runs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT NOT NULL,
        finished_at TEXT,
        details TEXT NOT NULL DEFAULT ''
      );
    SQL
  end

  def self.seed_from_stories_json(db)
    payload = JSON.parse(File.read(STORIES_PATH))
    project = payload['project'] || {}

    story_rows = payload.fetch('stories', []).map.with_index do |story, index|
      [
        story['id'],
        story['title'],
        story['goal'],
        story['description'],
        story['suggestedSolution'] || '',
        JSON.generate(story['acceptanceCriteria'] || []),
        story.dig('cucumberTest', 'feature') || '',
        story.dig('cucumberTest', 'scenario') || '',
        JSON.generate(story.dig('cucumberTest', 'steps') || []),
        story['estimateHours'] || 0,
        story['actualHours'],
        story['status'] || 'planned',
        story['githubIssueUrl'] || '',
        story['githubPrUrl'] || '',
        JSON.generate(story['dependencies'] || []),
        JSON.generate(story['labels'] || []),
        index,
        Time.now.iso8601
      ]
    end

    story_rows.each do |row|
      db.execute(<<~SQL, row)
        INSERT INTO stories (
          story_key, title, goal, description, solution, acceptance_criteria,
          cucumber_feature, cucumber_scenario, cucumber_steps, estimate_hours,
          actual_hours, status, github_issue_url, github_pr_url, dependencies,
          labels, position, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(story_key) DO UPDATE SET
          title = excluded.title,
          goal = excluded.goal,
          description = excluded.description,
          solution = excluded.solution,
          acceptance_criteria = excluded.acceptance_criteria,
          cucumber_feature = excluded.cucumber_feature,
          cucumber_scenario = excluded.cucumber_scenario,
          cucumber_steps = excluded.cucumber_steps,
          estimate_hours = excluded.estimate_hours,
          actual_hours = excluded.actual_hours,
          status = excluded.status,
          github_issue_url = excluded.github_issue_url,
          github_pr_url = excluded.github_pr_url,
          dependencies = excluded.dependencies,
          labels = excluded.labels,
          position = excluded.position,
          updated_at = excluded.updated_at
      SQL
    end

    if project['name']
      now = Time.now.iso8601
      project_params = [
        project['name'],
        project['github_url'] || '',
        project['staging_url'] || '',
        project['description'] || '',
        now,
        now,
        project['name']
      ]
      db.execute(<<~SQL, project_params)
        INSERT INTO projects (name, github_url, staging_url, description, created_at, updated_at)
        SELECT ?, ?, ?, ?, ?, ?
        WHERE NOT EXISTS (SELECT 1 FROM projects WHERE name = ?)
      SQL
    end
  end

  def self.seed_default_projects(db)
    return unless db.get_first_value('SELECT COUNT(1) FROM projects').to_i.zero?

    now = Time.now.iso8601
    defaults = [
      [DEFAULT_PROJECT_NAME, 'https://github.com/example/devconsole', 'https://staging.example.local', 'פאנל פנימי לניהול פרויקטים, סיפורים ו-Sentry']
    ]
    defaults.each do |name, github_url, staging_url, description|
      db.execute('INSERT INTO projects (name, github_url, staging_url, description, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
                 [name, github_url, staging_url, description, now, now])
    end
  end

  def self.seed_sentry_data(db)
    return unless db.get_first_value('SELECT COUNT(1) FROM sentry_issues').to_i.zero?

    now = Time.now.iso8601
    sample_issues = [
      ['SENTRY-214', 'Checkout flow error spikes', 'error', 'assaf', 'production', 'open', 'https://sentry.example.local/organizations/devconsole/issues/214/', 'Checkout page throws 500 under load'],
      ['SENTRY-208', 'Hebrew login validation warning', 'warn', 'qa-team', 'staging', 'investigating', 'https://sentry.example.local/organizations/devconsole/issues/208/', 'Translation fallback missing in login flow'],
      ['SENTRY-201', 'CI worker timeout', 'info', 'devops', 'production', 'resolved', 'https://sentry.example.local/organizations/devconsole/issues/201/', 'Worker finished after retry']
    ]

    sample_issues.each do |row|
      db.execute(<<~SQL, [row[0], row[1], row[2], row[3], row[4], row[5], row[6], now, now, 1, row[7], 'devconsole', now])
        INSERT INTO sentry_issues (
          sentry_key, title, level, user, environment, status, url,
          first_seen_at, last_seen_at, event_count, message, project_name, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      SQL
    end

    return unless db.get_first_value('SELECT COUNT(1) FROM sentry_releases').to_i.zero?

    sample_releases = [
      ['SENTRY-REL-1', '2026.07.30.1', 'production', 'https://sentry.example.local/releases/2026.07.30.1/', now, 14, 6],
      ['SENTRY-REL-2', '2026.07.29.2', 'staging', 'https://sentry.example.local/releases/2026.07.29.2/', now, 9, 4]
    ]

    sample_releases.each do |row|
      db.execute(<<~SQL, [row[0], row[1], row[2], row[3], row[4], row[5], row[6], now])
        INSERT INTO sentry_releases (
          release_key, version, environment, url, released_at, commit_count, user_count, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      SQL
    end
  end

  def self.refresh_external_sources!(db, reason:)
    refresh_github_projects!(db, reason: reason)
    refresh_sentry_from_config!(db)
  end

  def self.refresh_github_projects!(db, reason:)
    now = Time.now.iso8601
    db.execute('UPDATE projects SET last_synced_at = ?, updated_at = ? WHERE github_url != ""', [now, now])
    db.execute('INSERT INTO sync_runs (source, status, started_at, finished_at, details) VALUES (?, ?, ?, ?, ?)',
               ['github', 'ok', now, now, "Refreshed on #{reason}"])
  rescue StandardError => e
    db.execute('INSERT INTO sync_runs (source, status, started_at, finished_at, details) VALUES (?, ?, ?, ?, ?)',
               ['github', 'error', now, now, e.message])
  end

  def self.refresh_sentry_from_config!(db)
    now = Time.now.iso8601
    api_url = ENV['SENTRY_API_URL'].to_s.strip
    token = ENV['SENTRY_AUTH_TOKEN'].to_s.strip

    if api_url.empty?
      db.execute('INSERT INTO sync_runs (source, status, started_at, finished_at, details) VALUES (?, ?, ?, ?, ?)',
                 ['sentry', 'ok', now, now, 'Used seeded Sentry data'])
      return
    end

    uri = URI(api_url)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{token}" unless token.empty?
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(request) }

    raise "Sentry refresh failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    payload = JSON.parse(response.body)
    issues = payload['issues'] || payload['events'] || []
    releases = payload['releases'] || []

    issues.each do |issue|
      issue_params = [
        issue['key'] || issue['id'] || issue['title'],
        issue['title'] || issue['message'] || 'Sentry issue',
        (issue['level'] || 'info').downcase,
        issue['user'] || '',
        issue['environment'] || '',
        issue['status'] || 'open',
        issue['url'] || '',
        issue['firstSeen'] || issue['first_seen_at'] || now,
        issue['lastSeen'] || issue['last_seen_at'] || now,
        issue['count'] || issue['event_count'] || 1,
        issue['message'] || issue['title'] || '',
        issue['project'] || 'devconsole',
        now
      ]
      db.execute(<<~SQL, issue_params)
        INSERT INTO sentry_issues (
          sentry_key, title, level, user, environment, status, url,
          first_seen_at, last_seen_at, event_count, message, project_name, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(sentry_key) DO UPDATE SET
          title = excluded.title,
          level = excluded.level,
          user = excluded.user,
          environment = excluded.environment,
          status = excluded.status,
          url = excluded.url,
          last_seen_at = excluded.last_seen_at,
          event_count = excluded.event_count,
          message = excluded.message,
          project_name = excluded.project_name,
          updated_at = excluded.updated_at
      SQL
    end

    releases.each do |release|
      release_params = [
        release['key'] || release['version'],
        release['version'] || release['key'],
        release['environment'] || '',
        release['url'] || '',
        release['released_at'] || now,
        release['commit_count'] || 0,
        release['user_count'] || 0,
        now
      ]
      db.execute(<<~SQL, release_params)
        INSERT INTO sentry_releases (
          release_key, version, environment, url, released_at, commit_count, user_count, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(release_key) DO UPDATE SET
          version = excluded.version,
          environment = excluded.environment,
          url = excluded.url,
          released_at = excluded.released_at,
          commit_count = excluded.commit_count,
          user_count = excluded.user_count,
          updated_at = excluded.updated_at
      SQL
    end

    db.execute('INSERT INTO sync_runs (source, status, started_at, finished_at, details) VALUES (?, ?, ?, ?, ?)',
               ['sentry', 'ok', now, now, "Refreshed from #{api_url}"])
  rescue StandardError => e
    db.execute('INSERT INTO sync_runs (source, status, started_at, finished_at, details) VALUES (?, ?, ?, ?, ?)',
               ['sentry', 'error', now, now, e.message])
  end

  def upsert_project_from_params(params)
    now = Time.now.iso8601
    project_id = params['id'].to_s.strip
    name = params['name'].to_s.strip
    github_url = params['github_url'].to_s.strip
    staging_url = params['staging_url'].to_s.strip
    description = params['description'].to_s.strip

    halt 422, 'Project name is required' if name.empty?

    if project_id.match?(/\A\d+\z/)
      db.execute(<<~SQL, [name, github_url, staging_url, description, now, project_id.to_i])
        UPDATE projects
        SET name = ?, github_url = ?, staging_url = ?, description = ?, updated_at = ?
        WHERE id = ?
      SQL
    else
      db.execute(<<~SQL, [name, github_url, staging_url, description, now, now])
        INSERT INTO projects (name, github_url, staging_url, description, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
      SQL
    end

    self.class.refresh_github_projects!(db, reason: 'project update')
  end

  def delete_project(project_id)
    return unless project_id.to_s.match?(/\A\d+\z/)

    db.execute('DELETE FROM projects WHERE id = ?', project_id.to_i)
  end

  configure do
    set :root, File.expand_path(__dir__)
    set :database_path, DATABASE_PATH
    FileUtils.mkdir_p(File.dirname(DATABASE_PATH))

    db = SQLite3::Database.new(DATABASE_PATH)
    db.results_as_hash = true
    # db.type_translation = true  # Not supported in sqlite3 > 1.7
    set :db, db

    initialize_schema(db)
    seed_from_stories_json(db)
    seed_default_projects(db)
    seed_sentry_data(db)
    refresh_external_sources!(db, reason: 'startup')
  end

  def demo_logs
    [
      { 'timestamp' => '2026-07-30T09:15:12Z', 'level' => 'info', 'user' => 'assaf', 'message' => 'Started sync job' },
      { 'timestamp' => '2026-07-30T09:18:44Z', 'level' => 'warn', 'user' => 'qa-team', 'message' => 'Slow response detected' },
      { 'timestamp' => '2026-07-30T09:22:01Z', 'level' => 'error', 'user' => 'ops', 'message' => 'Connection dropped while syncing data' },
      { 'timestamp' => '2026-07-30T09:25:33Z', 'level' => 'debug', 'user' => 'assaf', 'message' => 'Inspecting run context' },
      { 'timestamp' => '2026-07-30T09:31:09Z', 'level' => 'info', 'user' => 'devops', 'message' => 'Sync job finished' }
    ]
  end
end
