# GitHub Integration Guide

This project uses **`octokit`** gem - the official Ruby client for GitHub API.

## Setup & Authentication

### 1. Generate GitHub Personal Access Token

1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select required scopes:
   - `repo` - Full control of private repositories
   - `workflow` - Update GitHub Action workflows
   - `read:org` - Read organization data
4. Copy the token (you'll only see it once!)

### 2. Set Environment Variables

```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
export GITHUB_REPO="owner/repository"
```

Or set them in your shell profile:
```bash
echo 'export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"' >> ~/.bashrc
echo 'export GITHUB_REPO="owner/repository"' >> ~/.bashrc
source ~/.bashrc
```

## Usage

### In Your Ruby Code

```ruby
require_relative 'lib/github_client'

# Initialize client
client = GitHubClient.new(token: ENV['GITHUB_TOKEN'], repo: 'owner/repo')

# Fetch issues
issues = client.fetch_issues(state: 'open')
issues.each do |issue|
  puts "##{issue[:number]}: #{issue[:title]}"
end

# Fetch pull requests
prs = client.fetch_pulls(state: 'open')
prs.each do |pr|
  puts "PR ##{pr[:number]}: #{pr[:title]} (reviews: #{pr[:review_count]})"
end

# Fetch CI workflow runs
workflows = client.fetch_workflow_runs
workflows.each do |run|
  puts "#{run[:workflow]}: #{run[:conclusion]} (#{run[:status]})"
end

# Export all data to JSON
client.export_to_json('output.json')
```

### Using the Export Script

```bash
GITHUB_TOKEN="ghp_xxx" GITHUB_REPO="owner/repo" ruby scripts/export_github_data.rb
```

This generates a JSON file like:
```json
{
  "repository": "owner/repo",
  "exported_at": "2026-07-30T15:45:00.000Z",
  "user": {
    "login": "username",
    "name": "Full Name"
  },
  "authenticated": true,
  "issues": [...],
  "pull_requests": [...],
  "workflows": [...]
}
```

## Available Methods

### Reading Data

| Method | Description | Returns |
|--------|-------------|---------|
| `fetch_issues(repo, state, labels)` | Fetch issues with metadata | Array of issue hashes |
| `fetch_pulls(repo, state, include_reviews)` | Fetch PRs with review status | Array of PR hashes |
| `fetch_workflow_runs(repo)` | Fetch CI workflow runs | Array of run hashes |
| `export_to_json(repo, output_file)` | Export all data to JSON | Boolean |

### Writing Data

| Method | Description | Returns |
|--------|-------------|---------|
| `update_issue(issue_number, updates)` | Update issue title, labels, state, etc | Boolean |
| `approve_pull_request(pr_number, comment)` | Approve a PR with optional comment | Boolean |
| `merge_pull_request(pr_number, message, method)` | Merge PR (squash/merge/rebase) | Boolean |
| `add_label(issue_number, labels)` | Add labels to issue | Boolean |

## Example: Complete Workflow

```ruby
require_relative 'lib/github_client'

client = GitHubClient.new(ENV['GITHUB_TOKEN'], 'owner/repo')

# Find open issues with "bug" label
bugs = client.fetch_issues(state: 'open', labels: ['bug'])

# Find PRs that fix those bugs
prs = client.fetch_pulls(state: 'open')

prs.each do |pr|
  if pr[:title].include?('fix bug')
    # Approve the PR
    client.approve_pull_request(pr[:number], "Looks good! 👍")
    
    # Merge it
    client.merge_pull_request(pr[:number], merge_method: 'squash')
    
    # Add success label to referenced issue
    client.add_label(bugs.first[:number], ['verified-fixed'])
  end
end

# Export updated data
client.export_to_json('github_status.json')
```

## Gem Features

- **Read Operations**: Issues, PRs, commits, workflows, deploy keys, webhooks, etc.
- **Write Operations**: Create/update issues, approve/merge PRs, manage labels
- **Rate Limiting**: 
  - Unauthenticated: 60 API calls/hour
  - Authenticated: 5,000 API calls/hour
- **Auto-pagination**: Automatically handles paginated results
- **Error Handling**: Built-in error handling with Octokit::NotFound, Octokit::Unauthorized, etc.

## JSON Export Format

```json
{
  "repository": "octokit/octokit.rb",
  "exported_at": "2026-07-30T15:45:00.000Z",
  "user": {
    "login": "github_username",
    "name": "Your Name"
  },
  "authenticated": true,
  "issues": [
    {
      "id": 123456,
      "number": 42,
      "title": "Bug: Something is broken",
      "state": "open",
      "created_at": "2026-07-15T10:00:00Z",
      "updated_at": "2026-07-30T10:00:00Z",
      "labels": ["bug", "critical"],
      "milestone": "v2.0.0",
      "assignee": "developer_name",
      "url": "https://github.com/...",
      "body": "Issue description..."
    }
  ],
  "pull_requests": [
    {
      "id": 654321,
      "number": 99,
      "title": "Fix: Something is better",
      "state": "open",
      "author": "contributor_name",
      "reviews": [
        {
          "author": "reviewer",
          "state": "APPROVED",
          "submitted_at": "2026-07-29T15:00:00Z"
        }
      ],
      "mergeable": true,
      "merged": false,
      "url": "https://github.com/..."
    }
  ],
  "workflows": [
    {
      "workflow": "Tests",
      "status": "completed",
      "conclusion": "success",
      "event": "push",
      "branch": "main",
      "created_at": "2026-07-30T12:00:00Z",
      "url": "https://github.com/..."
    }
  ]
}
```

## Troubleshooting

### Rate Limit Exceeded
- Use authentication token (5,000 calls/hour vs 60)
- Reduce API calls by using `per_page: 100` parameter
- Wait 1 hour for rate limit reset

### Authentication Failed
- Verify token is correctly set: `echo $GITHUB_TOKEN`
- Check token hasn't expired
- Verify token has required scopes

### Connection Issues
- Check firewall/proxy settings
- Verify internet connection
- Try with `https://api.github.com` explicitly

## Integration with DevConsole

This can be integrated into the DevConsole app to:
1. Sync GitHub issues into SQLite database
2. Display in the Stories dashboard
3. Track PR reviews and CI status
4. Auto-merge verified PRs
5. Update issue statuses based on PR merges

See `app.rb` for Sinatra integration points.
