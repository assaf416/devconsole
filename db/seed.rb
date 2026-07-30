#!/usr/bin/env ruby
# encoding: utf-8
# Seed database with sample projects

require 'sqlite3'
require_relative '../app'

db = SQLite3::Database.new('db/devconsole.sqlite3')
db.results_as_hash = true

DevConsoleApp.initialize_schema(db)

now = Time.now.iso8601

# Sample projects
projects = [
  {
    name: 'מרכז הבקרה למפתחים',
    github_url: 'https://github.com/example/devconsole',
    staging_url: 'https://staging-devconsole.example.com',
    description: 'ממשק ניהול מאחד לפרויקטים, בדיקות, לוגים וסנכרון GitHub/Sentry.'
  },
  {
    name: 'API ממשק אחד',
    github_url: 'https://github.com/example/api-gateway',
    staging_url: 'https://api-staging.example.com',
    description: 'ממשק כניסה מרכזי ל-microservices עם OAuth2, logging וניטור.'
  },
  {
    name: 'מערכת ניהול תוכן',
    github_url: 'https://github.com/example/cms',
    staging_url: 'https://cms-staging.example.com',
    description: 'פלטפורמה לייצור, עריכה ופרסום תוכן ממולא בעברית.'
  },
  {
    name: 'לוח בקרה ניתוח נתונים',
    github_url: 'https://github.com/example/analytics',
    staging_url: 'https://analytics-staging.example.com',
    description: 'דשבורד בזמן אמת לנתוני משתמשים, אירועים וביצועים.'
  },
  {
    name: 'שרת אימות משתמשים',
    github_url: 'https://github.com/example/auth-server',
    staging_url: 'https://auth-staging.example.com',
    description: 'שירות ניהול זהויות עם SAML/OIDC וניהול הרשאות.'
  }
]

projects.each do |project|
  begin
    db.execute(<<~SQL, [project[:name], project[:github_url], project[:staging_url], project[:description], now, now])
      INSERT INTO projects (name, github_url, staging_url, description, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
    SQL
    puts "✓ Created project: #{project[:name]}"
  rescue SQLite3::ConstraintException => e
    puts "⚠ Project already exists: #{project[:name]}"
  end
end

puts "\n✅ Seed data loaded successfully!"
db.close
