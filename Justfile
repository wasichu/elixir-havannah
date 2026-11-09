set positional-arguments

# List development commands.
default:
    @just --list

# Bootstrap after mise install.
setup:
    mix local.hex --force
    mix local.rebar --force
    npm ci
    mix setup

# Start Phoenix with live reloading.
dev:
    mix phx.server

# Start Phoenix in IEx.
console:
    iex -S mix phx.server

# Run tests, optionally passing a file, line, or options.
test *args:
    mix test "$@"

format:
    mix format

# Required source, lint, and test checks.
check:
    mix precommit

# Check without silently fixing source or the lockfile.
ci:
    mix format --check-formatted
    mix deps.unlock --check-unused
    mix precommit
    mix assets.build

assets:
    mix assets.build

# Build a production release without deploying.
release:
    MIX_ENV=prod mix assets.deploy
    MIX_ENV=prod mix release --overwrite

outdated:
    mix hex.outdated --all

# Update the lockfile within constraints, then verify.
update:
    mix deps.update --all
    npm update
    just check
    just assets

# Deploy with flyctl after checks. Keep one Machine: match state is node-local.
deploy: ci
    flyctl deploy --ha=false
