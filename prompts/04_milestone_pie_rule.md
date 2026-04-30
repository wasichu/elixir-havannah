# Havannah – Milestone 4: Pie Rule (Side Swap)

This project is a Phoenix LiveView implementation of the strategy game Havannah.

At this stage, the application already supports:

* game sessions (human vs human, human vs AI)
* turn enforcement
* full Havannah win detection (bridge, fork, ring)

The goal of this milestone is to implement the **pie rule**, allowing the second player to optionally swap sides after the first move.

---

## Goals

Implement a clean and minimal version of the pie rule:

* After the first move, the second player can choose to:

  * **swap sides** with the first player
  * **keep sides** and continue normally

The implementation must integrate cleanly with the existing game state and architecture.

---

## Core Requirements

### Game Phases

Introduce explicit game phases:

* `:opening` → before the first move
* `:pie_decision` → after the first move, awaiting decision
* `:playing` → normal gameplay
* `:game_over` → already exists

Flow:

1. Game starts in `:opening`
2. First player makes a move
3. Game transitions to `:pie_decision`
4. Second player chooses swap or keep
5. Game transitions to `:playing`

---

### Pie Rule Behavior

* Only the **second player** may make the pie decision
* The decision is available **only once**, immediately after the first move

If the second player chooses:

#### Swap

* Swap the **side assignments** between players
* Do NOT modify the board
* Do NOT replay moves
* The existing first move now belongs to the swapped side

#### Keep

* No changes to side assignments
* Continue normal play

---

### Player and Side Model

* Preserve the existing design:

  * board stores side ownership (e.g., `:blue`, `:red`)
  * players are mapped to sides

* The pie rule must operate by **swapping player-to-side mapping only**

* Do NOT:

  * rewrite the board
  * reassign stones
  * introduce special-case hacks

---

### Turn Handling

After the pie decision:

* The game continues with the correct next player
* Ensure turn order is consistent regardless of swap or keep

Be explicit and careful about which player moves next.

---

### AI Integration

For `:human_vs_ai` games:

* If the AI is the second player:

  * automatically decide whether to swap or keep
  * for now, choose randomly

* If the human is the second player:

  * present UI for the decision

* After the decision:

  * continue normal gameplay
  * trigger AI moves as usual if it is the AI’s turn

---

### LiveView / UI

When in `:pie_decision` phase:

* Show a clear prompt:

  * “Do you want to swap sides?”

* Provide buttons:

  * “Swap”
  * “Keep”

* Only the second player should be able to interact

* Spectators cannot make the decision

After decision:

* remove the prompt
* resume normal game UI

---

### Game Process

* The pie decision must be handled through the game process (GenServer)

* Validate:

  * correct phase
  * correct player making the decision

* Broadcast updated state to all subscribers

---

### Testing

Add tests for:

* correct phase transitions:

  * `:opening` → `:pie_decision` → `:playing`

* swap behavior:

  * player-to-side mapping is swapped
  * board remains unchanged

* keep behavior:

  * no changes to mapping

* turn correctness after decision

* AI decision:

  * triggers automatically when AI is second player

* invalid actions:

  * cannot swap after phase ends
  * wrong player cannot make decision

---

## Constraints

* Do NOT modify existing win detection logic
* Do NOT introduce unnecessary abstractions
* Keep implementation simple and readable
* Avoid duplicating logic already present in the game process

---

## Process

Before writing code:

* Briefly explain:

  * how phases will be represented
  * how side swapping will be implemented cleanly

Then implement step by step.

---

## Deliverables

* Updated game state with pie rule phases
* Pie decision handling in game process
* UI for swap/keep decision
* AI integration for pie rule
* Tests covering all behaviors
* Brief explanation of design decisions
