There is a bug in the pie rule implementation.

Currently, when the second player chooses to swap, they effectively get two moves:

* they take over the first move
* and then immediately place another stone

This is incorrect.

Correct behavior:

1. Player 1 makes the first move
2. Game enters `:pie_decision`
3. Player 2 chooses swap or keep

After the decision:

* If **keep**:

  * Player 2 moves next

* If **swap**:

  * Player 2 takes ownership of the first move
  * Side assignments are swapped
  * The board remains unchanged
  * Player 1 moves next

This invariant must hold:

after first move:
phase = :pie_decision
current_player = :player2

after keep:
phase = :playing
current_player = :player2

after swap:
phase = :playing
current_player = :player1

Task:

* Fix the pie rule logic so that turn order is correct after swap
* Do NOT rewrite the board
* Do NOT change the player/side model
* Keep changes minimal and localized to the game process logic
* Ensure AI behavior still works correctly

Add or update tests to verify:

* swap does NOT result in two consecutive moves by the same player
* correct player moves next after swap and keep

Before coding, briefly explain what is currently wrong and how you will fix it.

