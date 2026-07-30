# frozen_string_literal: true

# Only run SimpleCov in the top-level test process (not in CLI subprocess tests)
unless ENV['DEVCONSOLE_NO_COVERAGE']
  require 'simplecov'
  require 'simplecov_json_formatter'

  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter
  ]

  SimpleCov.start do
    enable_coverage :branch

    add_filter '/features/'
    add_filter '/db/'
    add_filter '/documentation/'

    add_group 'App', 'app.rb'
    minimum_coverage 50
  end
end
