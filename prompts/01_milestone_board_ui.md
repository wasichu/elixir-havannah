This project is a Phoenix LiveView implementation of the strategy game Havannah, which will eventually support both human vs human play and human vs AI play.

For this milestone, focus ONLY on the board UI and basic placement interaction.
Do NOT implement AI, multiplayer, or Havannah win detection yet.

## Goals

Build a polished, responsive Havannah board interface (base-10, 10 cells per side) with click-to-place interaction and clean architecture that supports future expansion.

## Core Requirements

### Board and Coordinates

* Use **axial coordinates (q, r)** for all board logic (this is required).
* The board must be a true hexagon shape for a size-10 Havannah board.
* Valid cells must satisfy the correct axial constraints for a hex board (radius = 9).
* Provide helper functions for:

  * valid cell detection
  * board generation
  * neighbor lookup

### Game Model

* The board must store **side ownership**, not player identity.

  * Example: `:blue` / `:red` or `:side_a` / `:side_b`
* Players must be mapped to sides.
* Do NOT hardcode assumptions like “player1 is always blue”.
* The design should support a future “pie rule” (side swapping after the first move), so player identity must be decoupled from side/color ownership.
* Include a basic game struct that tracks:

  * board state
  * players and their assigned side
  * current player
  * phase (use something like `:playing` even if only one phase is used for now)

### Interaction (Milestone 1 only)

* Clicking an empty cell places a stone for the current player’s side.
* Turns alternate after each valid placement.
* Occupied cells are not clickable.
* No movement logic—this is a placement game.
* No win detection yet.
* No AI yet.

### UI / LiveView

* Use LiveView for rendering and event handling only.
* Keep game logic out of LiveView—place it in pure Elixir modules.
* Show:

  * whose turn it is
  * basic game status
  * highlight for the last move played

### Rendering

* Prefer **SVG rendering** for the hex grid.
* The board should visually look like a proper hexagonal Havannah board.
* Include:

  * hover styling for empty cells
  * clear visual distinction between sides
  * last-move highlight
* Layout should be clean and reasonably responsive.

### Architecture

* Separate concerns clearly:

  * Board / coordinate logic
  * Game state and rules (even if minimal for now)
  * LiveView UI layer
* Avoid overengineering.
* Avoid putting logic in the LiveView.

### Testing

* Add tests for:

  * board generation
  * valid cell membership
  * neighbor calculation
  * basic placement and turn alternation

## Constraints

* No database
* No AI
* No multiplayer
* No Havannah win condition logic
* Do not introduce unnecessary abstractions
* Keep the code clean and understandable

## Process

Before writing code, briefly explain your approach and architecture in a concise way.
Then proceed with implementation.

## Deliverables

* LiveView and any components needed for the board UI
* Pure Elixir modules for board and game logic
* Tests for core board and placement behavior
* A short explanation of the file structure and design decisions

