# Havannah – Milestone 3: Game Rules and Win Detection

This project is a Phoenix LiveView implementation of the strategy game Havannah.

At this stage, the application already supports:

* game sessions
* human vs human and human vs AI modes
* turn enforcement
* stone placement on a hexagonal board (axial coordinates)

The goal of this milestone is to implement **correct Havannah win detection** while preserving the existing clean architecture.

---

## Goals

Add full win detection for Havannah:

* bridge (connect two corners)
* fork (connect three edges)
* ring (enclose one or more cells)

The implementation must be correct, testable, and clearly structured.

---

## Core Requirements

### General

* All rule logic must live in **pure Elixir modules**
* Do NOT place rule logic inside LiveView
* Do NOT break existing game session architecture
* The game process should call into rule logic after each move

---

## Step-by-Step Implementation (IMPORTANT)

Follow this sequence strictly. Do NOT jump directly to ring detection.

---

### Step 1: Connected Groups

* Implement logic to compute **connected groups of stones** for a given side

* Use axial neighbor relationships (6 directions)

* Provide a function like:

  get_group(board, coord) -> MapSet of coordinates

* Add tests for:

  * single stone
  * multi-stone connected group
  * disconnected groups

---

### Step 2: Board Classification (Edges and Corners)

* Define the **6 corners** and **6 edges** of the board using axial coordinates

* Provide functions to determine:

  * whether a coordinate is on a corner
  * whether a coordinate is on a specific edge

* Add tests to verify correct classification

---

### Step 3: Bridge Detection

* A bridge occurs when a connected group touches **two distinct corners**

* For each connected group:

  * track which corners it touches
  * if >= 2 distinct corners → win

* Add thorough tests

---

### Step 4: Fork Detection

* A fork occurs when a connected group touches **three distinct edges**

* For each connected group:

  * track which edges it touches
  * if >= 3 distinct edges → win

* Add thorough tests

---

### Step 5: Ring Detection (IMPORTANT)

* A ring occurs when a player forms a loop that **encloses at least one cell**

* Implement a correct and understandable approach:

  * prefer clarity over cleverness
  * avoid overly compact or “magic” solutions

Suggested approach (one option):

* After each move:

  * consider the player’s stones as blocking cells
  * perform a flood fill from outside the board
  * any empty cells NOT reachable are enclosed
  * verify that the enclosing boundary belongs to the player

Alternative correct approaches are acceptable if well-structured and testable.

* Add strong tests for:

  * simple rings
  * non-rings that look similar
  * edge-adjacent shapes that should NOT count
  * minimal enclosing loops

---

## Integration

* After each move:

  * evaluate win conditions for the current player
  * if a win is detected:

    * update game state to `:game_over`
    * record the winner
    * prevent further moves

---

## Game State

* Extend the existing game state to include:

  * game status (`:playing`, `:game_over`)
  * winner (if any)

* Do NOT implement the pie rule yet

* Do NOT change player/side mapping design

---

## LiveView Updates

* Reflect game-over state in UI:

  * display winner
  * disable further moves

Keep UI changes minimal and clean.

---

## Testing

This milestone requires strong test coverage.

Add tests for:

* connected group detection
* edge and corner classification
* bridge detection
* fork detection
* ring detection (multiple scenarios)
* full move sequences leading to wins

---

## Constraints

* Do NOT introduce unnecessary abstractions
* Do NOT optimize prematurely
* Prioritize correctness and clarity
* Avoid large monolithic functions
* Keep modules focused and readable

---

## Process

Before writing code:

* Briefly explain your approach to:

  * connected groups
  * edge/corner classification
  * ring detection strategy

Then implement step by step.

---

## Deliverables

* Rule logic modules
* Integration into game process
* Updated game state with win handling
* Comprehensive tests
* Brief explanation of design decisions

