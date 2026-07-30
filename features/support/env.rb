# encoding: utf-8
require_relative 'simplecov'
require 'rack/test'
require 'rspec/matchers'
require_relative '../../app'

World(Rack::Test::Methods, RSpec::Matchers)

DevConsoleApp.set :environment, :test
DevConsoleApp.set :host_authorization, { permitted_hosts: [] }

# Provide access to the app's database
def app_db
  app.db
end

def app
  DevConsoleApp
end
