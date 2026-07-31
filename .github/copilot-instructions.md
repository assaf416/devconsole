# GitHub Copilot – Project Instructions

## Stack
- **Backend**: Ruby on Rails / Sinatra / Go
- **Database**: SQLite3 (dev), PostgreSQL (prod)
- **Testing**: Cucumber BDD in Hebrew (`# language: he`)
- **CI**: GitHub Actions
- **Cloud**: DigitalOcean, Hetzner

## Language
- All GitHub **issue titles and bodies** must be written in **Hebrew**.
- All **Cucumber feature files** must be written in Hebrew using `# language: he`.
- Code, variable names, and comments stay in English.

## Development Workflow
1. For each story, open a GitHub issue in Hebrew with: title, change description, estimated hours, suggested Hebrew Cucumber test, and proposed solution.
2. Create a new branch named after the story ID + title (no spaces, use hyphens), e.g. `ST-023-some-feature`.
3. Write Hebrew Cucumber tests first (BDD / test-first).
4. Implement the fix or feature.
5. Make sure all tests are green before committing.
6. Commit, push, open a PR, and merge to `main`.
7. Close the GitHub issue and update the issue body with actual development time.
	- Add link to the feature branch
	- Add link to the merged PR
	- Add links to all created/modified Cucumber feature files and step definition files
	- Add actual development hours

## Cucumber / BDD Rules
- Feature files live in `features/` with `.feature` extension.
- Step definitions in `features/step_definitions/`.
- Support files in `features/support/`.
- Always use `# language: he` at the top of every feature file.
- Hebrew keywords: `תכונה`, `תרחיש`, `בהינתן`, `וכאשר`, `אז`, `ו-`.
- Run with: `CUCUMBER_PUBLISH_QUIET=true bundle exec cucumber`

## Code Review Standards
- Every PR must have at least one Hebrew Cucumber test covering the changed behaviour.
- No PR merges if tests are red.
- Issue titles must be in Hebrew.
- Branch names must follow `ST-XXX-description` pattern.

## MCP Servers Available
- `github` – issues, PRs, Actions, repos (OAuth via Copilot)
- `digitalocean` – Droplets, App Platform, Kubernetes
- `hetzner` – servers, networks, volumes
