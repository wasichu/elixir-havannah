# Renovate maintenance

Dependency updates use the hosted [Renovate GitHub App](https://github.com/apps/renovate),
with access limited to `wasichu/elixir-havannah`. Its repository policy is `renovate.json`.
There is no self-hosted Renovate workflow or `RENOVATE_TOKEN` secret.

Grant the app access only to the intended repositories. The configuration must be
on the default branch before the hosted service can apply it. Check the app's
installation settings and repository Dependency Dashboard when diagnosing updates.
Do not run a second Renovate installation against the same repository.
