# devconsole

Sinatra + SQLite3 implementation of the Hebrew RTL dev console mockup.

## Run

1. `bundle install`
2. `bundle exec ruby app.rb`
3. Open `http://localhost:4567`

## Pages

- `/projects` for project CRUD with `name`, `github_url`, and `staging_url`
- `/stories` for the imported story catalog
- `/logs` for the log viewer demo
- `/sentry/overview`, `/sentry/issues`, `/sentry/releases` for Sentry screens
- `/tests` for the Cucumber-style test workspace
