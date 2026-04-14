# Havannah – Milestone 2: Game Sessions, Modes, and Turn Enforcement

This project is a Phoenix LiveView implementation of the strategy game Havannah, which will eventually support both human vs human play and human vs AI play.

For this milestone, focus on **game session architecture, player roles, and turn-based interaction**.

Do NOT implement Havannah win detection or the pie rule yet.

---

## Goals

Transform the existing board UI into a real playable application with:

* shared game sessions
* human vs human and human vs AI modes
* proper player assignment
* enforced turn-taking
* basic random AI integration

The game should feel like a real multiplayer app, even though the game logic is still minimal.

---

## Core Requirements

### Game Sessions

* Introduce an **authoritative game process per game** (e.g., a GenServer).

* Each game must have a unique game ID.

* LiveViews should connect to and subscribe to updates from the game process.

* All moves must go through the game process (not directly through LiveView state).

* Use a `DynamicSupervisor` (or similar) to manage game processes.

* Provide a way to:

  * create a new game
  * look up an existing game by ID

---

### Game Modes

Support two modes:

* `:human_vs_human`
* `:human_vs_ai`

Game mode should be set when the game is created.

---

### Player Model

* Players must be separate from sides (as designed in Milestone 1).

* Each player should have:

  * a side (`:blue` / `:red` or similar)
  * a type (`:human` or `:ai`)

* Do NOT hardcode player-to-side relationships.

* The design should support a future “pie rule” (side swapping), so keep player identity decoupled from side ownership.

---

### Player Assignment

For human vs human:

* First user to join becomes Player 1
* Second user becomes Player 2
* Additional users are spectators

For human vs AI:

* One player is human
* One player is AI
* The human should be assigned one side, AI the other

Keep this simple—no accounts or authentication needed.

---

### Turn Enforcement

* Only the player whose turn it is may make a move.

* Spectators cannot make moves.

* If it is the AI’s turn, human input must be ignored or disabled.

* All move validation must happen in the game process.

---

### Interaction Flow

* A move is placing a stone on an empty cell (same as Milestone 1).

* After a valid move:

  * update the game state
  * broadcast the update to all connected LiveViews

* In `:human_vs_ai` mode:

  * after a human move, trigger an AI move automatically
  * introduce a small delay (e.g., 200–500ms) for UX

---

### AI (Basic)

* Implement a simple random AI:

  * choose randomly from available legal moves
* AI should use the same game API as human moves
* Do NOT implement advanced AI logic

---

### LiveView Responsibilities

* Connect to a game by ID (via params or route)

* Subscribe to game state updates

* Render:

  * board
  * current player / turn
  * player identity (you vs opponent vs spectator)
  * game mode
  * shareable game link

* Send move events to the game process

* Do NOT store authoritative game state in the LiveView

---

### Routing / UX

* Provide a way to:

  * create a new game (with mode selection)
  * navigate to `/game/:id`

* Display a shareable link for human vs human games

* Show clear UI for:

  * “Your turn”
  * “Waiting for opponent”
  * “AI thinking”

---

### Architecture

Maintain clean separation:

* Pure modules:

  * game state and logic
  * board and coordinate helpers
  * AI module

* Stateful process:

  * game server (authoritative state)

* UI:

  * LiveView layer only handles rendering and events

Avoid putting logic into LiveView.

---

### Testing

Add tests for:

* game process behavior:

  * creating a game
  * joining players
  * enforcing turns
  * rejecting invalid moves

* AI:

  * returns only legal moves

* game state transitions:

  * correct player alternation
  * correct side usage

---

## Constraints

* No database required
* No Havannah win detection yet
* No pie rule implementation yet
* No overengineering (keep it simple and clear)
* Keep code modular and maintainable

---

## Process

Before writing code, briefly explain your architecture and approach.

Then proceed with implementation.

---

## Deliverables

* Game process implementation (e.g., GenServer + supervisor)
* Updated LiveView with session-based gameplay
* Player assignment and mode handling
* Random AI integration
* Tests for session and turn logic
* Brief explanation of design decisions

