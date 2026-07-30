#!/usr/bin/env ruby
# encoding: utf-8

# Example GitHub data exporter script

require_relative '../lib/github_client'

# Usage:
# GITHUB_TOKEN=ghp_xxxx GITHUB_REPO=octocat/Hello-World ruby scripts/export_github_data.rb

token = ENV['GITHUB_TOKEN']
repo = ENV['GITHUB_REPO'] || 'octokit/octokit.rb'  # Default to demo repo

unless token
  puts "⚠ Warning: GITHUB_TOKEN not set (running in unauthenticated mode)"
  puts "For higher rate limits and private repos:"
  puts "  export GITHUB_TOKEN=<token>"
  puts ""
end

puts "🔗 Connecting to GitHub..."
client = GitHubClient.new(token, repo)

if client.authenticated?
  user = client.user
  puts "✓ Authenticated as: #{user.login} (#{user.name})"
else
  puts "⚠ Running in unauthenticated mode (limited API calls)"
end

puts "\n📊 Fetching data from: #{repo}"
puts "  • Issues..."
puts "  • Pull Requests..."
puts "  • CI Workflows..."

# Export all data to JSON
output_file = "github_data_#{repo.gsub('/', '_')}.json"
if client.export_to_json(repo, output_file)
  puts "\n✅ Data exported successfully!"
  
  # Read and display summary
  begin
    data = JSON.parse(File.read(output_file))
    puts "\n📈 Summary:"
    puts "  Issues:           #{data['issues'].length}"
    puts "  Pull Requests:    #{data['pull_requests'].length}"
    puts "  Workflow Runs:    #{data['workflows'].length}"
    puts "\nFile: #{output_file}"
  rescue => e
    puts "Error reading export: #{e.message}"
  end
else
  puts "\n❌ Export failed"
  exit 1
end

# Example: List open issues with specific label
puts "\n\n📝 Example: Fetching open issues..."
issues = client.fetch_issues(repo, state: 'open')
puts "Found #{issues.length} open issues:"
issues.first(3).each do |issue|
  puts "  ##{issue[:number]}: #{issue[:title]}"
end

# Example: List open PRs
puts "\n\n🔀 Example: Fetching open pull requests..."
prs = client.fetch_pulls(repo, state: 'open')
puts "Found #{prs.length} open PRs:"
prs.first(3).each do |pr|
  puts "  ##{pr[:number]}: #{pr[:title]} (#{pr[:review_count]} reviews)"
end

puts "\n\n✨ To use in your app:"
puts "  require_relative 'lib/github_client'"
puts "  client = GitHubClient.new(token, 'owner/repo')"
puts "  issues = client.fetch_issues"
puts "  prs = client.fetch_pulls"
puts "  client.export_to_json('output.json')"
