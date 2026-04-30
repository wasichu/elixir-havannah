# Update: Havannah Rules Wording and Definitions

The current rules text in the UI needs to be updated to improve clarity and correctness, especially for the ring condition.

## Required Changes

### General

* Replace vague wording like “chain of stones” with:

  * “a single connected group of stones”

* Ensure all win conditions explicitly refer to **connected groups**, not just placement.

---

### Bridge

Replace with:

> Connect two different corners of the board with a single connected group of your stones.

Notes:

* Must be two distinct corners
* Must be one connected group

---

### Fork

Replace with:

> Connect three different edges of the board with a single connected group of your stones.

Notes:

* Edges must be distinct
* Corners do not count as edges for this condition

---

### Ring

Replace with:

> Form a loop of your stones that encloses at least one cell not occupied by you, such that the enclosed area has no path to the edge of the board.

Notes:

* The enclosed area may contain:

  * empty cells
  * opponent stones
  * or both
* The enclosed region must be completely cut off from the board boundary
* The loop must be formed by a single connected group of stones

---

## UI Considerations

* Use this wording in the "How to Play" modal
* Keep text concise and readable
* Rely on diagrams to reinforce understanding (especially for ring)
* Do not include overly long or theoretical explanations

---

## Non-Goals

* Do NOT change any existing win detection logic
* Do NOT modify game rules implementation
* This is a wording/clarity update only

---

## Deliverable

* Updated rules text in the UI modal reflecting the above definitions

