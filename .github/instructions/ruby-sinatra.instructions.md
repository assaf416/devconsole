---
applyTo: "**/*.rb"
---

# Ruby / Sinatra Conventions

- Use `frozen_string_literal: true` at the top of every file
- Prefer Sinatra modular style (`class App < Sinatra::Base`)
- Database access via SQLite3 with hashed results (`results_as_hash = true`)
- Validate all user inputs at route boundaries; never trust raw params
- Helpers go in the `helpers do` block inside the app class
- Keep routes thin – extract logic into helper methods or service objects
- Always test routes via Hebrew Cucumber scenarios, not unit tests only
