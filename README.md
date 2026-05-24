# Havannah (Phoenix LiveView)

A real-time implementation of the strategy game [**Havannah**][hw], built with **Elixir**, **Phoenix LiveView**, and a custom hex board engine.

[Play in your browser][hhp] against another human or a simple AI.

---

## 🎮 What is Havannah?

Havannah is a two-player abstract strategy game played on a hexagonal grid.

Players take turns placing stones, trying to achieve one of three winning conditions:

* **Bridge**: connect two corners of the board
* **Fork**: connect three different edges
* **Ring**: form a loop that encloses one or more cells

To balance first-move advantage, the game includes the **pie rule**:
after the first move, the second player can choose to swap sides.

---

## ✨ Features

* ♟️ **Human vs Human** play via shared game link
* 🤖 **Human vs AI** mode (random-move AI for now)
* 🔁 **Rematch support**
* 🏳️ **Resign option** with confirmation
* ⏱️ **Per-move timer** (default: 5 minutes)
* ⚖️ **Pie rule** implementation
* 🧠 Full **win detection**:

  * bridge
  * fork
  * ring
* 🎨 Clean UI with **LiveView-driven updates**
* 📐 Custom **hex grid engine using axial coordinates**

---

## 🧱 Tech Stack

* **Elixir**
* **Phoenix 1.8 (LiveView)**
* **GenServer-based game processes**
* **SVG-based hex board rendering**

---

## 🚀 Getting Started

### Prerequisites

* Elixir (>= 1.15 recommended)
* Erlang/OTP
* Node.js (for assets)

### Setup

```bash
git clone https://github.com/wasichu/elixir-havannah
cd elixir-havannah

mix deps.get
mix setup
mix phx.server
```

Then open:

```
http://localhost:4000
```

---

## 🧠 Architecture Overview

The project is structured around a clean separation of concerns:

* **Game logic (pure Elixir)**

  * board representation (axial coordinates)
  * move validation
  * win detection (bridge, fork, ring)

* **Game process (GenServer)**

  * authoritative game state
  * turn enforcement
  * timer handling
  * AI move triggering

* **LiveView UI**

  * rendering the board
  * handling user interactions
  * subscribing to game updates

This allows the UI, rules, and game state to evolve independently.

---

## ⚖️ Pie Rule Implementation

After the first move:

* the game enters a decision phase
* the second player may:

  * **keep** their side
  * or **swap** sides with the first player

Swapping only changes player-to-side assignment.
The board state remains unchanged.

---

## ⏱️ Timers

* Each move has a time limit (default: 5 minutes)
* If a player exceeds the limit, they lose on time
* Timer enforcement is handled server-side

---

## 🧪 Testing

Run tests with:

```bash
mix test
```

Tests cover:

* board generation
* connected group detection
* win conditions
* game state transitions
* session and turn enforcement

---

## 🗺️ Potential Improvements

* Smarter AI (beyond random moves)
* UI polish and animations
* Move history / replay
* Mobile improvements
* Spectator enhancements

---

## 🤝 Contributing

This project was built as an exploration of:

* Phoenix LiveView
* real-time multiplayer architecture
* non-trivial board game logic

Feel free to open issues or PRs.

---

## 📜 License

MIT (or update as appropriate)

---

## 🙌 Acknowledgments

* Havannah designed by Christian Freeling
* Inspired by classic connection games like Hex

---

## 💬 Notes

This project intentionally emphasizes:

* clarity over cleverness
* correctness in game logic
* clean architecture with minimal overengineering

---

[hw]: https://en.wikipedia.org/wiki/Havannah_(board_game)
[hhp]: https://havannah.slowinput.org
