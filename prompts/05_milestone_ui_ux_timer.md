# Havannah – Milestone 5: UI, UX, Game Controls, and Timers

This project is a Phoenix LiveView implementation of Havannah.

At this stage, the application already supports:

* human vs human games
* human vs AI games
* full Havannah win detection
* pie rule support
* game-over state

The goal of this milestone is to improve the game UI and add missing gameplay controls.

Do NOT implement stronger AI in this milestone. Better AI will be Milestone 6.

---

## Goals

Improve the user experience by adding:

* rematch behavior
* resign behavior
* improved navigation/header
* rules/how-to-play modal
* winner details showing the win condition
* per-move timers for human players

---

## 1. Rematch

On the game page:

* Replace the existing `New Game` button with `Rematch`.
* `Rematch` should only be visible or clickable once the current game is over.
* Before game over, do not show it or keep it disabled.

When clicked:

* Start a new game with the same mode.
* Preserve the same general setup where reasonable.
* Redirect players to the new game.

Keep this simple.

---

## 2. Resign

Add a `Resign` option during active games.

Behavior:

* Only active human players can resign.
* Spectators cannot resign.
* Resign should not be available after the game is already over.

Confirmation:

* Clicking `Resign` should open a confirmation prompt/modal.
* The confirmation should have:

  * `Yes, resign`
  * `No, cancel`

If confirmed:

* The resigning player loses.
* The other player wins.
* Game state transitions to `:game_over`.
* UI should clearly show that the game ended by resignation.

---

## 3. Header / Top Menu Redesign

The top navigation/header needs to be updated.

### Logo

Replace the default Phoenix logo and `v1.8.5` branding.

Use a Havannah-related logo/mark instead.

Requirements:

* The logo should link back to the home page / new game dialog.
* The same logo should also be used as the site favicon.
* Keep the design simple and lightweight.
* Do not introduce heavy image dependencies unless necessary.

Suggested logo direction:

* A small hexagonal board icon
* Or a stylized hex cell cluster
* Or an abstract Havannah “ring / fork / bridge” mark

Prefer an inline SVG if practical.

---

### Header Links

Update the right-side header links:

* Replace `Website` with `Rules` or `How to Play`.

* `Rules` / `How to Play` should open a modal explaining the rules of Havannah.

* Replace the existing GitHub link with:

  https://github.com/wasichu/elixir-havannah

* Leave the dark/light toggle as-is.

* Remove the `Get Started ->` button entirely.

---

## 4. Rules / How to Play Modal

Add a modal that explains how to play Havannah.

The modal should summarize:

* Players alternate placing stones on empty hexes.
* The pie rule after the first move.
* A player wins by forming one of:

  * bridge: connecting two corners
  * fork: connecting three board edges
  * ring: enclosing one or more cells
* Resignation.
* Timers, once implemented.

Use concise wording.

Do not dump a long Wikipedia article into the modal. Summarize the rules clearly in the app’s own words.

---

## 5. Show Win Condition

When someone wins, the UI should show both:

* which player won
* how they won

Examples:

* `Blue wins by bridge`
* `Red wins by fork`
* `Blue wins by ring`
* `Red wins by resignation`
* `Blue wins on time`

This means the game state should record the win reason / win condition.

Possible values:

* `:bridge`
* `:fork`
* `:ring`
* `:resignation`
* `:timeout`

Do not rely only on a generic winner field.

---

## 6. Per-Move Timer

Add a per-move timer for human players.

Default:

* 5 minutes per move

Behavior:

* The timer starts when it becomes a human player’s turn.
* The timer resets after each completed move.
* If the timer expires, that player loses.
* Game state transitions to `:game_over`.
* Winner is the opposing player.
* Win reason should be `:timeout`.

Important:

* Timer logic must be enforced by the authoritative game process.
* Do not rely only on LiveView client-side display.
* The LiveView can display the timer, but the game process must enforce timeout behavior.

AI behavior:

* AI should not need a visible 5-minute timer.
* If it is AI’s turn, existing AI move behavior should continue as before.

UI:

* Show the active human player’s remaining time.
* Make the timer visually clear but not obnoxious.
* When the game ends on time, show that clearly in the winner message.

---

## Architecture Requirements

Keep the existing architecture clean:

* Game rules and game state belong in pure/domain modules where appropriate.
* Authoritative state and timeout enforcement belong in the game process.
* LiveView handles rendering and user events.
* Do not move core game logic into LiveView.

---

## Testing

Add or update tests for:

* rematch availability only after game over
* resignation flow
* resignation winner and win reason
* win condition display data
* timeout behavior
* timer reset after valid moves
* timer not allowing moves after timeout
* header/modal behavior where practical

---

## Constraints

* Do NOT implement stronger AI yet.
* Do NOT rewrite existing win detection.
* Do NOT break existing pie rule behavior.
* Do NOT introduce database persistence.
* Keep changes focused and incremental.

---

## Process

Before writing code:

* Briefly explain the planned changes.
* Identify which changes affect game state versus UI only.
* Explain how timer enforcement will work without relying only on the client.

Then implement step by step.

---

## Deliverables

* Updated header/navigation
* Havannah logo/favicon
* Rules/how-to-play modal
* Rematch behavior
* Resign behavior with confirmation
* Winner display including win condition
* Per-move human timer with timeout loss
* Updated tests
* Brief explanation of design decisions
