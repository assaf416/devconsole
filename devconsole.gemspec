# frozen_string_literal: true

require_relative 'lib/devconsole/version'

Gem::Specification.new do |spec|
  spec.name          = 'devconsole'
  spec.version       = DevConsole::VERSION
  spec.authors       = ['assaf416']
  spec.summary       = 'Hebrew RTL developer console — manage projects, run Cucumber tests, and manage GitHub tickets from the CLI.'
  spec.description   = spec.summary
  spec.license       = 'MIT'
  spec.require_paths = ['lib']
  spec.files         = Dir['lib/**/*.rb', 'bin/*', 'views/**/*', 'public/**/*',
                           'app.rb', 'config.ru', 'db/**/*.rb', 'features/**/*',
                           '*.md', '*.gemspec']
  spec.bindir        = 'bin'
  spec.executables   = ['devconsole']
  spec.required_ruby_version = '>= 3.0'

  spec.add_dependency 'thor',          '~> 1.3'
  spec.add_dependency 'sinatra',       '~> 4.1'
  spec.add_dependency 'sinatra-contrib','~> 4.1'
  spec.add_dependency 'sqlite3',       '~> 1.7'
  spec.add_dependency 'puma',          '~> 6.6'
  spec.add_dependency 'rack',          '~> 3.0'
  spec.add_dependency 'rackup',        '~> 2.0'
  spec.add_dependency 'tilt',          '~> 2.5'
  spec.add_dependency 'octokit',       '~> 7.1'

  spec.add_development_dependency 'cucumber',       '~> 9.2'
  spec.add_development_dependency 'rack-test',      '~> 2.1'
  spec.add_development_dependency 'rspec-expectations', '~> 3.13'
  spec.add_development_dependency 'cucumber-core', '~> 13.0'
  spec.add_development_dependency 'simplecov',     '~> 0.22'
  spec.add_development_dependency 'simplecov-json','~> 0.2'
end
