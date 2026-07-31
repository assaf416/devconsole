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

## Deployment (Hetzner + Kamal)

This repo is configured to deploy to your Hetzner server `46.62.141.240` with Kamal.

### Files added

- `config/deploy.yml` (Kamal target config)
- `Dockerfile` (Sinatra container)
- `.dockerignore`
- `.kamal/secrets.example`

### 1. Server prerequisites (one-time on Hetzner)

Run on `46.62.141.240` as root:

```bash
apt-get update
apt-get install -y docker.io curl git
systemctl enable --now docker
```

### 2. Local Kamal secrets (for manual deploy)

```bash
cp .kamal/secrets.example .kamal/secrets
```

Fill `.kamal/secrets` with real values:

- `KAMAL_REGISTRY_USERNAME`
- `KAMAL_REGISTRY_PASSWORD` (GHCR PAT with `write:packages`)
- `SENTRY_API_URL` (optional)
- `SENTRY_AUTH_TOKEN` (optional)

### 3. Configure hostname

Update `proxy.host` in `config/deploy.yml` from `devconsole.example.com` to your real domain.

### 4. Manual deploy

```bash
bundle install
bundle exec kamal setup
bundle exec kamal deploy
```

### 5. CI auto-deploy on `main`

The GitHub workflow now deploys automatically after tests pass on push to `main`.

Add these repository/environment secrets:

- `HETZNER_SSH_PRIVATE_KEY`
- `KAMAL_REGISTRY_USERNAME`
- `KAMAL_REGISTRY_PASSWORD`
- `SENTRY_API_URL` (optional)
- `SENTRY_AUTH_TOKEN` (optional)

Recommended: store them under GitHub Environment `production`.
