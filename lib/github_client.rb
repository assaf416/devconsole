# encoding: utf-8
require 'octokit'
require 'json'

class GitHubClient
  def initialize(token = nil, repo = nil)
    @token = token || ENV['GITHUB_TOKEN']
    @repo = repo || ENV['GITHUB_REPO']
    
    if @token
      @client = Octokit::Client.new(access_token: @token)
      @client.auto_paginate = true
    else
      @client = Octokit::Client.new
    end
  end

  def authenticated?
    !@token.nil? && @token != ''
  end

  def user
    @client.user if authenticated?
  end

  # Fetch all issues with labels and milestones
  def fetch_issues(repo = @repo, state: 'all', labels: [])
    return [] unless repo
    
    options = { state: state, per_page: 100 }
    options[:labels] = labels.join(',') if labels && labels.any?
    
    @client.issues(repo, options).map do |issue|
      {
        id: issue.id,
        number: issue.number,
        title: issue.title,
        state: issue.state,
        created_at: issue.created_at,
        updated_at: issue.updated_at,
        labels: issue.labels.map(&:name),
        milestone: issue.milestone&.title,
        assignee: issue.assignee&.login,
        url: issue.html_url,
        body: issue.body
      }
    end
  rescue Octokit::NotFound
    puts "Repository not found: #{repo}"
    []
  end

  # Fetch all pull requests with review status
  def fetch_pulls(repo = @repo, state: 'all', include_reviews: true)
    return [] unless repo
    
    @client.pulls(repo, { state: state, per_page: 100 }).map do |pr|
      pull_data = {
        id: pr.id,
        number: pr.number,
        title: pr.title,
        state: pr.state,
        created_at: pr.created_at,
        updated_at: pr.updated_at,
        author: pr.user.login,
        labels: pr.labels.map(&:name),
        assignee: pr.assignee&.login,
        url: pr.html_url,
        mergeable: pr.mergeable,
        merged: pr.merged,
        merged_at: pr.merged_at,
        merged_by: pr.merged_by&.login
      }
      
      # Only fetch reviews if authenticated (to save API calls)
      if include_reviews && authenticated?
        begin
          reviews = @client.pull_request_reviews(repo, pr.number)
          pull_data[:review_count] = reviews.length
          pull_data[:reviews] = reviews.map do |r|
            {
              author: r.user.login,
              state: r.state,
              submitted_at: r.submitted_at
            }
          end
        rescue => e
          pull_data[:review_count] = 0
          pull_data[:reviews] = []
        end
      else
        pull_data[:review_count] = 0
        pull_data[:reviews] = []
      end
      
      pull_data
    end
  rescue Octokit::NotFound
    puts "Repository not found: #{repo}"
    []
  end

  # Fetch CI workflow runs
  def fetch_workflow_runs(repo = @repo)
    return [] unless repo
    
    workflows = @client.workflows(repo)
    
    workflows.map do |workflow|
      runs = @client.workflow_runs(repo, workflow.id, { per_page: 10 })
      
      runs.map do |run|
        {
          id: run.id,
          workflow: workflow.name,
          status: run.status,
          conclusion: run.conclusion,
          event: run.event,
          branch: run.head_branch,
          commit_sha: run.head_sha,
          created_at: run.created_at,
          updated_at: run.updated_at,
          url: run.html_url,
          run_number: run.run_number
        }
      end
    end.flatten
  rescue Octokit::NotFound => e
    puts "Could not fetch workflows: #{e.message}"
    []
  end

  # Export all data to JSON
  def export_to_json(repo = @repo, output_file = "github_data.json")
    return false unless repo
    
    workflows = authenticated? ? fetch_workflow_runs(repo) : []
    
    data = {
      repository: repo,
      exported_at: Time.now.iso8601,
      user: authenticated? ? { login: user.login, name: user.name } : nil,
      authenticated: authenticated?,
      issues: fetch_issues(repo),
      pull_requests: fetch_pulls(repo, include_reviews: authenticated?),
      workflows: workflows
    }
    
    File.write(output_file, JSON.pretty_generate(data))
    puts "✓ Exported to #{output_file}"
    true
  rescue => e
    puts "Error exporting: #{e.message}"
    false
  end

  # Update an issue
  def update_issue(issue_number, updates, repo = @repo)
    return false unless repo
    
    @client.update_issue(repo, issue_number, updates)
    true
  rescue => e
    puts "Error updating issue: #{e.message}"
    false
  end

  # Approve a pull request
  def approve_pull_request(pr_number, comment = "", repo = @repo)
    return false unless repo
    
    @client.create_pull_request_review(repo, pr_number, event: 'APPROVE', body: comment)
    true
  rescue => e
    puts "Error approving PR: #{e.message}"
    false
  end

  # Merge a pull request
  def merge_pull_request(pr_number, commit_message = nil, merge_method = 'squash', repo = @repo)
    return false unless repo
    
    options = { merge_method: merge_method }
    options[:commit_message] = commit_message if commit_message
    
    @client.merge_pull_request(repo, pr_number, "Auto-merged", options)
    true
  rescue => e
    puts "Error merging PR: #{e.message}"
    false
  end

  # Add label to issue
  def add_label(issue_number, labels, repo = @repo)
    return false unless repo
    
    @client.add_labels_to_an_issue(repo, issue_number, labels)
    true
  rescue => e
    puts "Error adding label: #{e.message}"
    false
  end
end
