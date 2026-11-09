# Working on Havannah

Havannah is an Elixir/Phoenix LiveView game. Read this file, `README.md`, and the
relevant source/tests before editing. These instructions apply throughout the repo.

## Development and verification

- `mise.toml` pins Erlang, Elixir, Node, and Just. Run `mise install`, then use
  `mise exec -- just setup`. Use the same toolchain locally, in CI, and in Docker.
- `Justfile` is the supported command interface. `just dev` starts Phoenix;
  `just console` starts it in IEx; `just test [file:line]` runs focused tests.
- Run `just check` (`mix precommit`) after changes and fix failures. It compiles
  with warnings as errors, removes unused locks, formats, runs strict Credo,
  and tests with warnings as errors.
- Run `just ci` before handing off. It first checks formatting and unused locks
  without repairing them, then runs precommit and builds CSS/JS. For dependency,
  release, or runtime changes, also run `just release`. CI builds and boots Docker.
  `just deploy` checks and publishes through `flyctl`; run it only when deployment
  is requested. Keep Fly at one Machine and preserve the explicit origin allowlist.
- `just outdated` reports all outdated Hex packages; `npm outdated` checks frontend
  packages. `just update` refreshes both lockfiles within their constraints and
  verifies source and assets. Broaden constraints deliberately for major upgrades.
- Read `mix help <task>` before unfamiliar Mix tasks. Do not delete dependencies
  or build caches as a routine troubleshooting step.
- Never edit `deps/`, `_build/`, `node_modules/`, or generated `priv/static/assets/`.
  Commit `mix.lock` and `package-lock.json` with dependency changes.

## Architecture and invariants

- `Havannah.Board`: fixed radius-nine axial hex grid (271 cells). Validate integer
  coordinates at the domain boundary. The board maps cells to `nil`, `:blue`, or `:red`.
- `Havannah.Rules`: pure connectivity and bridge/fork/ring detection. Corners do
  not count as edges. Rings may enclose empty, opposing, or friendly stones;
  a three-stone triangle is not a ring. Keep traversal work linear in visited cells.
- `Havannah.Game`: pure state transitions and pie rule. Player identity and stone
  side are separate. Swapping exchanges sides without changing the board; after
  a swap the first player moves next. Return tagged errors for invalid actions.
- `Havannah.GameServer`: sole authority for a match, serialized through GenServer.
  Enforce participation, turn, phase, readiness, and timeouts here even when the UI
  hides controls. Keep browser session identifiers out of snapshots and PubSub.
- `Havannah.GameSupervisor` and `Havannah.GameRegistry`: temporary game processes
  addressed by opaque IDs. Never restart a crashed match as an empty game under
  its old ID. Missing or disappeared games must return `{:error, :not_found}`.
- `HavannahWeb.LobbyLive` / `GameLive`: validate browser payloads, call the domain,
  and render snapshots. Subscribe before joining/fetching to avoid missed updates.
  Do not claim player slots during disconnected HTTP rendering.
- Game state lives in memory on one BEAM node. There is no Ecto, database, account
  authentication, or durable match recovery. DNS clustering alone does not provide
  distributed Registry lookup. Do not imply otherwise in code or documentation.
- Move clocks use reference-tagged Erlang timer messages. Cancel old timers and
  ignore stale references. Expose wall-clock deadlines only for display; the
  server's timer is authoritative. Keep one countdown timer per connected LiveView.

## Elixir and OTP practices

- Prefer small functions, pattern matching, explicit data, and a pure domain with
  thin process/UI boundaries. Extract helpers around a coherent responsibility,
  not simply to add layers. Put one module in each file.
- Add specs/docs for public domain APIs and meaningful types for new data structures.
  Use `Game.t()`/`Board.t()` in specs, not bare struct patterns.
- Never convert client strings into atoms, including with `String.to_existing_atom/1`.
  Match the supported string values explicitly. Validate coordinates with guards
  or non-raising parsing. Invalid client data must not crash a match or LiveView.
- Access struct fields with `struct.field`; use form access only on `to_form` results.
  Lists are not indexable via `list[index]`; use patterns or `Enum.at/2`.
- Bind the result of `if`/`case`/`cond`; rebinding inside a branch does not escape it.
  Predicate names end with `?`. Avoid user-controlled atoms and unbounded processes.
- Use named supervised OTP services and supervised test processes. Tie delayed work
  to the state that scheduled it. Bound any new background concurrency and timeouts.
- Use standard date/time modules. If HTTP is needed, prefer Req; it is not currently
  a dependency, so add it explicitly rather than assuming the generated guide is correct.

## Phoenix, HEEx, and assets

- Start LiveView templates with `<Layouts.app flash={@flash}>`. This app currently
  has no `current_scope`; introduce it only with an actual authentication design.
- Use verified `~p` routes, `<.link navigate={...}>`/`patch={...}` and
  `push_navigate`/`push_patch`. Router scopes already provide the web module alias.
- Use HEEx (`~H`/`.heex`), `{...}` for attributes and values, and `<%= ... %>` for
  blocks. Use list syntax for conditional classes and HEEx comments (`<%!-- --%>`).
  Literal code braces need `phx-no-curly-interpolation`.
- Use `<.form for={@form}>`, assigned with `to_form/2`, and the shared `<.input>`
  component for new forms. Access fields via `@form[:field]`, never a changeset.
  Fully style inputs when overriding their default class.
- Use `<.icon>` for Heroicons. Only layouts may invoke the flash group component.
  Prefer function components; introduce LiveComponents only for independent state.
- Use streams for growing collections. The fixed, bounded board is an ordinary
  assign by design. Stream parents need unique IDs and `phx-update="stream"`,
  and their children need stream IDs. Never use deprecated append/prepend updates.
- Keep behavior in `assets/js/` and import it through `app.js`. Do not embed scripts
  in HEEx. DOM-owning hooks require an ID and `phx-update="ignore"`.
- Preserve Tailwind v4's `@import "tailwindcss" source(none)` and `@source` directives.
  Do not use `@apply`. Build new components with Tailwind utilities/custom CSS;
  the existing legacy daisyUI styles are maintained as a locked npm dependency.
- Only `app.js` and `app.css` are entry bundles. Import dependencies into them;
  do not add CDN scripts/styles or manually vendor package releases.
- Give important controls stable DOM IDs. Preserve responsive layouts, accessible
  names, keyboard operation, focus indicators, and reduced-motion preferences.

## Testing strategy

- Add regression tests for changed behavior before or alongside a fix. Cover invalid
  inputs, authorization, stale timers, pie swaps, and terminal phases when relevant.
- Keep Board/Rules/Game tests pure and async. Start processes with `start_supervised!`
  and unique game IDs. Do not change application-wide config from async tests.
- Exercise real timer callbacks using controlled options and reference-tagged
  messages; synchronize with GenServer calls or PubSub assertions. Avoid sleeps,
  probabilistic assertions, and fragile assumptions about randomly chosen AI cells.
- LiveView tests use `Phoenix.LiveViewTest` and stable IDs with `element/2` /
  `has_element?/2`. Assert behavior and selected DOM structure, not whole HTML
  strings. Use LazyHTML to inspect a focused fragment when diagnosing failures.
- Focus tests while iterating, then run the complete required checks. Report exactly
  what ran and any limitations; do not claim Docker/browser checks from unit tests.

## Dependency automation and agent workflow

- `renovate.json` manages Hex, npm, mise, GitHub Actions, Docker, and the pinned
  Tailwind/esbuild binaries in `config/config.exs`. Keep that syntax recognizable
  by the custom managers. Review major changes and toolchain compatibility.
- GitHub Actions are pinned to release commit SHAs. Keep workflow permissions
  minimal. CI must run on PRs without deployment credentials. Do not add automatic
  deployment or automerging as part of routine dependency maintenance.
- Dependency updates use the hosted Renovate GitHub App, scoped to this repository.
  Keep its policy in `renovate.json`; do not add a self-hosted workflow or personal
  access token. Maintainer notes live in `.github/renovate.md`. Never print credentials,
  commit secrets, or depend on them in tests.
- Inspect `git status` before editing; preserve unrelated work. Read neighboring
  code and tests, make reviewable changes, and avoid speculative frameworks.
- For broad work, state the scope and verification plan briefly, then proceed.
  Surface discovered correctness/security issues and add focused regression coverage.
- Update README and this file when supported commands, architecture, invariants,
  or operational requirements change. Distinguish facts from future plans.
- Before handoff, inspect the diff, run the required checks, and report outcomes,
  residual risks, and any one-time setup. Do not commit, push, deploy, or send messages
  unless the user requests it. Use additional agents only when explicitly requested.
