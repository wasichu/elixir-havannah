# Havannah

A real-time [Havannah](https://en.wikipedia.org/wiki/Havannah_(board_game)) game built
with Elixir, Phoenix LiveView, and an SVG hex board. [Play online](https://havannah.slowinput.org).

Play against a friend through a shared match link or against a random-move AI.
The radius-nine board has 271 cells. Win by connecting two corners (bridge),
three distinct edges (fork), or forming a ring around one or more cells.
Corners do not count as edges; a ring may surround stones of either side.

After the opening move, the second player chooses whether to keep their side or
swap. Swapping exchanges player-to-color assignments without changing the board.
The first player then takes the next turn. Each human turn, including the pie
choice, has a five-minute server-enforced deadline. Players can also resign.

## Development

Install [mise](https://mise.jdx.dev/) and run:

```sh
mise install
mise exec -- just setup
mise exec -- just dev
```

Open <http://localhost:4000>. If mise is activated in your shell, use `just` directly.
`mise.toml` pins Erlang, Elixir, Node, and Just; CI reads the same file. Docker
pins matching language runtimes. No database setup is required.

| Command | Purpose |
| --- | --- |
| `just` | List commands |
| `just setup` | Install Hex/Rebar, fetch locked packages, build assets |
| `just dev` / `just console` | Phoenix server / server in IEx |
| `just test [file:line]` | All tests or a focused test |
| `just format` | Format Elixir and HEEx |
| `just check` | `mix precommit`: compile, unused locks, format, strict Credo, tests |
| `just ci` | Check formatting/locks, run precommit, compile frontend assets |
| `just assets` | Build CSS and JavaScript |
| `just release` | Build production assets and an OTP release without deploying |
| `just deploy` | Run checks and deploy with `flyctl` (no spare HA machine) |
| `just outdated` / `npm outdated` | Report stale Hex / frontend dependencies |
| `just update` | Update both lockfiles within constraints and run checks/assets |

Tailwind and esbuild binaries are pinned in `config/config.exs`. Phoenix browser
libraries come from the Hex dependencies, so their client and server versions stay
aligned. Topbar and the existing daisyUI styles use npm with a committed lockfile.
New UI components should use Tailwind utilities/custom CSS.

## Architecture

- `Board`, `Rules`, and `Game` are pure Elixir: coordinates, connectivity, win
  detection, pie decisions, and terminal transitions.
- `GameServer` serializes all actions, authorizes sessions, owns move/AI timers,
  and publishes sanitized snapshots through PubSub. Timer references prevent
  obsolete messages from advancing or ending a later turn.
- `GameSupervisor` starts temporary match processes; `GameRegistry` locates them.
  A crashed match disappears instead of silently restarting with an empty board.
- `LobbyLive` and `GameLive` render state and submit actions. Signed browser
  sessions preserve player slots across reconnects. Additional sessions spectate.

Matches are held in memory on one node. Restarts/deployments lose matches; games
and spectator assignments currently remain until the process/node stops. There is
no persistence, idle-game eviction, distributed match routing, or account system.
DNS clustering alone does not distribute the local Registry. Production hosting
must keep a match on its owning node; multi-node durability needs a separate design.

## Checks and automation

Tests cover pure rules, complete game transitions, server authorization/readiness,
AI turns, stale timers, snapshot privacy, LiveView multiplayer interaction, and
malformed browser payloads. Tests use supervised processes and controlled timer
messages rather than sleep-based timing assumptions.

`.github/workflows/ci.yml` runs locked dependency installation, formatting checks,
strict Credo, tests, asset compilation, and a production release build. A separate
job builds the deployment image and boots it for an HTTP smoke test.

The hosted Renovate GitHub App uses `renovate.json` to track Hex, npm, mise tools,
Docker images, GitHub Action pins, and
Tailwind/esbuild binary versions. Updates run weekly with a three-day release age;
lockfile maintenance is enabled, major upgrades stay reviewable, and automerge is off.
Keep Docker's Elixir/OTP/Node versions aligned when reviewing mise updates.

## Production

```sh
just release
SECRET_KEY_BASE=... PHX_HOST=localhost PHX_SERVER=true _build/prod/rel/havannah/bin/havannah start
```

Set a real secret and public hostname for production. `PORT` defaults to 4000;
`DNS_CLUSTER_QUERY` is optional. `Dockerfile` builds assets and the OTP release in
its builder stage and runs the release as an unprivileged user without Node/npm.
`fly.toml` configures the public hostname, 256 MiB shared CPU Machine, and HTTP health
check. Deploy with `just deploy` (requires `flyctl` authentication). Keep the app
at one Machine because matches use a local Registry; `--ha=false` avoids creating
a spare, and `flyctl scale count 1 --app elixir-havannah` corrects an existing
multi-Machine deployment. Both the public domain and app's `.fly.dev` hostname
are accepted as LiveView origins. Deployments restart the in-memory game processes.

See [AGENTS.md](AGENTS.md) for repository-specific implementation and verification guidance.
