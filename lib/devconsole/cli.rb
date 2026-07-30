# frozen_string_literal: true
# encoding: utf-8

require 'thor'
require 'fileutils'
require_relative 'version'

module DevConsole
  class CLI < Thor
    APP_ROOT = File.expand_path('../../..', __FILE__).freeze
    DB_PATH  = File.join(APP_ROOT, 'db', 'devconsole.sqlite3').freeze

    package_name 'devconsole'

    def self.exit_on_failure?
      true
    end

    # ─────────────────────────────────────────────────
    # VERSION / HELP
    # ─────────────────────────────────────────────────
    map %w[--version -v] => :version_cmd

    desc '--version', 'Show devconsole version'
    def version_cmd
      puts "devconsole v#{DevConsole::VERSION}"
    end

    # ─────────────────────────────────────────────────
    # SERVER
    # ─────────────────────────────────────────────────
    desc 'server', 'Start the DevConsole HTTP server'
    option :port, aliases: '-p', type: :numeric, default: 4567, desc: 'Port to listen on'
    option :host, aliases: '-b', type: :string,  default: '0.0.0.0', desc: 'Bind address'
    def server
      port = options[:port]
      host = options[:host]
      say "🚀  Starting DevConsole server on http://#{host == '0.0.0.0' ? '127.0.0.1' : host}:#{port}", :green
      Dir.chdir(APP_ROOT) do
        require_relative '../../app'
        require 'rack'
        require 'rackup'
        app = Rack::Builder.parse_file(File.join(APP_ROOT, 'config.ru'))
        Rackup::Server.start(app: app, Port: port, Host: host)
      end
    end

    # ─────────────────────────────────────────────────
    # DB
    # ─────────────────────────────────────────────────
    desc 'db COMMAND', 'Database operations: setup | migrate | seed'
    def db(command = nil)
      case command
      when 'setup', 'migrate'
        say "📦  Running database setup/migrate...", :cyan
        Dir.chdir(APP_ROOT) do
          require_relative '../../app'
          database = SQLite3::Database.new(DB_PATH)
          database.results_as_hash = true
          DevConsoleApp.initialize_schema(database)
          database.close
        end
        say "✓  Schema up-to-date at #{DB_PATH}", :green
      when 'seed'
        say "🌱  Seeding database...", :cyan
        Dir.chdir(APP_ROOT) do
          load File.join(APP_ROOT, 'db', 'seed.rb')
        end
      else
        say "Usage: devconsole db <setup|migrate|seed>", :yellow
        say ""
        say "  setup    — create database and apply schema"
        say "  migrate  — re-run schema (idempotent)"
        say "  seed     — load sample project data"
        exit 1
      end
    end

    # ─────────────────────────────────────────────────
    # TEST
    # ─────────────────────────────────────────────────
    desc 'test [PATH]', 'Run Cucumber tests. Pass a folder or .feature file, or omit to run all.'
    option :format, aliases: '-f', type: :string, default: 'progress', desc: 'Cucumber output format (progress|pretty)'
    option :tags,   aliases: '-t', type: :string, desc: 'Cucumber tag filter, e.g. @smoke'
    def test(path = nil)
      features_dir = File.join(APP_ROOT, 'features')

      target = if path
                 File.expand_path(path)
               else
                 features_dir
               end

      unless File.exist?(target)
        say "✗  Not found: #{target}", :red
        exit 1
      end

      args = [target,
              '--format', options[:format],
              '--publish-quiet']
      args += ['--tags', options[:tags]] if options[:tags]

      say "🧪  Running Cucumber: #{target}", :cyan
      Dir.chdir(APP_ROOT) do
        require 'cucumber'
        result = system('bundle', 'exec', 'cucumber', *args)
        exit(result ? 0 : 1)
      end
    end

    # ─────────────────────────────────────────────────
    # TICKET
    # ─────────────────────────────────────────────────
    desc 'ticket COMMAND', 'GitHub ticket/PR operations: open | close | merge-pr'
    option :repo,    aliases: '-r', type: :string, desc: 'GitHub repo (owner/repo). Defaults to GITHUB_REPO env var.'
    option :title,   aliases: '-T', type: :string, desc: 'Issue title (for open)'
    option :body,    aliases: '-B', type: :string, desc: 'Issue / PR body'
    option :number,  aliases: '-n', type: :numeric, desc: 'Issue or PR number (for close / merge-pr)'
    option :method,  aliases: '-m', type: :string,  default: 'squash', desc: 'Merge method: squash | merge | rebase'
    option :token,   type: :string, desc: 'GitHub token (defaults to GITHUB_TOKEN env var)'
    def ticket(command = nil)
      repo  = options[:repo]  || ENV['GITHUB_REPO']
      token = options[:token] || ENV['GITHUB_TOKEN']

      unless token
        say "✗  GITHUB_TOKEN not set. Use --token or export GITHUB_TOKEN=...", :red
        exit 1
      end

      require_relative '../github_client'
      client = GitHubClient.new(token, repo)

      case command
      when 'open'
        title = options[:title] || ask("Issue title: ")
        body  = options[:body]  || ''
        unless repo
          say "✗  --repo or GITHUB_REPO is required", :red; exit 1
        end
        issue = client.octokit.create_issue(repo, title, body)
        say "✓  Issue ##{issue.number} opened: #{issue.html_url}", :green

      when 'close'
        number = options[:number] || ask("Issue/PR number to close: ").to_i
        unless repo
          say "✗  --repo or GITHUB_REPO is required", :red; exit 1
        end
        client.octokit.close_issue(repo, number)
        say "✓  Issue/PR ##{number} closed", :green

      when 'merge-pr'
        number = options[:number] || ask("PR number to merge: ").to_i
        merge_method = options[:method]
        unless repo
          say "✗  --repo or GITHUB_REPO is required", :red; exit 1
        end
        result = client.octokit.merge_pull_request(repo, number, '', merge_method: merge_method)
        say "✓  PR ##{number} merged (#{merge_method}): #{result.sha}", :green

      else
        say "Usage: devconsole ticket <open|close|merge-pr> [options]", :yellow
        say ""
        say "  open      — create a new GitHub issue"
        say "              --repo, --title, --body"
        say "  close     — close an issue or PR"
        say "              --repo, --number"
        say "  merge-pr  — merge a pull request"
        say "              --repo, --number, --method (squash|merge|rebase)"
        say ""
        say "Environment variables: GITHUB_TOKEN, GITHUB_REPO"
        exit 1
      end
    rescue => e
      say "✗  #{e.message}", :red
      exit 1
    end
  end
end
