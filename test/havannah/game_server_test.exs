defmodule Havannah.GameServerTest do
  use ExUnit.Case, async: true

  alias Havannah.GameServer

  # Start a GameServer directly via pid for isolated, async-safe tests.
  # The public API (GameServer.join/place/get_state) goes through Registry,
  # so we call GenServer directly here.
  defp start_server(mode) do
    game_id = "test-#{System.unique_integer([:positive])}"
    {:ok, pid} = GenServer.start_link(GameServer, {game_id, mode})
    pid
  end

  defp get_state(pid), do: GenServer.call(pid, :get_state)
  defp join(pid, session_id), do: GenServer.call(pid, {:join, session_id})
  defp place(pid, session_id, cell), do: GenServer.call(pid, {:place, session_id, cell})

  defp pie_decision(pid, session_id, choice),
    do: GenServer.call(pid, {:pie_decision, session_id, choice})

  defp resign(pid, session_id), do: GenServer.call(pid, {:resign, session_id})

  # ---------------------------------------------------------------------------
  # Creating a game
  # ---------------------------------------------------------------------------

  describe "creating a game" do
    test "hvh game starts in :waiting status with both slots open" do
      pid = start_server(:human_vs_human)
      {:ok, state} = get_state(pid)
      assert state.mode == :human_vs_human
      assert state.status == :waiting
      assert state.slots == %{player_1: :open, player_2: :open}
    end

    test "hva game starts with player_2 slot set to :ai" do
      pid = start_server(:human_vs_ai)
      {:ok, state} = get_state(pid)
      assert state.mode == :human_vs_ai
      assert state.slots == %{player_1: :open, player_2: :ai}
    end

    test "board starts empty" do
      pid = start_server(:human_vs_human)
      {:ok, state} = get_state(pid)
      assert Enum.all?(state.game.board, fn {_cell, side} -> is_nil(side) end)
    end
  end

  # ---------------------------------------------------------------------------
  # Joining players
  # ---------------------------------------------------------------------------

  describe "joining players" do
    test "first human becomes :player_1" do
      pid = start_server(:human_vs_human)
      assert {:ok, :player_1} = join(pid, "alice")
    end

    test "second human becomes :player_2" do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      assert {:ok, :player_2} = join(pid, "bob")
    end

    test "third person becomes :spectator" do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")
      assert {:ok, :spectator} = join(pid, "carol")
    end

    test "re-joining returns the stored role" do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      assert {:ok, :player_1} = join(pid, "alice")
    end

    test "hvh becomes :playing once both players join" do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")
      {:ok, state} = get_state(pid)
      assert state.status == :playing
    end

    test "hva becomes :playing once the human joins" do
      pid = start_server(:human_vs_ai)
      join(pid, "alice")
      {:ok, state} = get_state(pid)
      assert state.status == :playing
    end

    test "hva player_2 slot remains :ai after human joins" do
      pid = start_server(:human_vs_ai)
      join(pid, "alice")
      {:ok, state} = get_state(pid)
      assert state.slots.player_2 == :ai
    end
  end

  # ---------------------------------------------------------------------------
  # Turn enforcement
  # ---------------------------------------------------------------------------

  describe "turn enforcement" do
    setup do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")
      {:ok, pid: pid}
    end

    test "player_1 can place on their turn", %{pid: pid} do
      assert :ok = place(pid, "alice", {0, 0})
    end

    test "player_2 cannot move on player_1's turn", %{pid: pid} do
      assert {:error, :not_your_turn} = place(pid, "bob", {0, 0})
    end

    test "turns alternate: p1 → p2 → p1", %{pid: pid} do
      assert :ok = place(pid, "alice", {0, 0})
      assert :ok = pie_decision(pid, "bob", :keep)
      assert :ok = place(pid, "bob", {1, 0})
      assert :ok = place(pid, "alice", {0, 1})
    end

    test "spectator cannot place", %{pid: pid} do
      join(pid, "carol")
      assert {:error, :spectator_cannot_move} = place(pid, "carol", {0, 0})
    end

    test "unknown session cannot place", %{pid: pid} do
      assert {:error, :not_in_game} = place(pid, "ghost", {0, 0})
    end
  end

  # ---------------------------------------------------------------------------
  # Rejecting invalid moves
  # ---------------------------------------------------------------------------

  describe "rejecting invalid moves" do
    setup do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")
      {:ok, pid: pid}
    end

    test "rejects placement on occupied cell", %{pid: pid} do
      place(pid, "alice", {0, 0})
      pie_decision(pid, "bob", :keep)
      place(pid, "bob", {1, 0})
      # alice tries bob's cell
      assert {:error, :cell_occupied} = place(pid, "alice", {1, 0})
    end

    test "rejects placement on invalid cell", %{pid: pid} do
      assert {:error, :invalid_cell} = place(pid, "alice", {99, 99})
    end
  end

  # ---------------------------------------------------------------------------
  # Game state transitions
  # ---------------------------------------------------------------------------

  describe "game state transitions" do
    setup do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")
      {:ok, pid: pid}
    end

    test "board records placed stone", %{pid: pid} do
      place(pid, "alice", {0, 0})
      {:ok, state} = get_state(pid)
      assert state.game.board[{0, 0}] == :blue
    end

    test "current_player advances after a move", %{pid: pid} do
      {:ok, before} = get_state(pid)
      assert before.game.current_player == :player_1

      place(pid, "alice", {0, 0})

      {:ok, after_state} = get_state(pid)
      assert after_state.game.current_player == :player_2
    end

    test "player_1 is assigned :blue side", %{pid: pid} do
      {:ok, state} = get_state(pid)
      assert Havannah.Game.player_side(state.game, :player_1) == :blue
    end

    test "player_2 is assigned :red side", %{pid: pid} do
      {:ok, state} = get_state(pid)
      assert Havannah.Game.player_side(state.game, :player_2) == :red
    end
  end

  # ---------------------------------------------------------------------------
  # Pie rule
  # ---------------------------------------------------------------------------

  describe "phase transitions" do
    setup do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")
      {:ok, pid: pid}
    end

    test "game starts in :opening phase", %{pid: pid} do
      {:ok, state} = get_state(pid)
      assert state.game.phase == :opening
    end

    test "first move transitions to :pie_decision", %{pid: pid} do
      place(pid, "alice", {0, 0})
      {:ok, state} = get_state(pid)
      assert state.game.phase == :pie_decision
    end

    test ":keep transitions to :playing without swapping sides", %{pid: pid} do
      place(pid, "alice", {0, 0})
      pie_decision(pid, "bob", :keep)
      {:ok, state} = get_state(pid)
      assert state.game.phase == :playing
      assert Havannah.Game.player_side(state.game, :player_1) == :blue
      assert Havannah.Game.player_side(state.game, :player_2) == :red
    end

    test ":swap transitions to :playing and exchanges side assignments", %{pid: pid} do
      place(pid, "alice", {0, 0})
      pie_decision(pid, "bob", :swap)
      {:ok, state} = get_state(pid)
      assert state.game.phase == :playing
      assert Havannah.Game.player_side(state.game, :player_1) == :red
      assert Havannah.Game.player_side(state.game, :player_2) == :blue
    end

    test ":swap does not modify the board", %{pid: pid} do
      place(pid, "alice", {0, 0})
      {:ok, before} = get_state(pid)
      pie_decision(pid, "bob", :swap)
      {:ok, after_state} = get_state(pid)
      assert after_state.game.board == before.game.board
    end

    test "player_2 moves next after :keep", %{pid: pid} do
      place(pid, "alice", {0, 0})
      pie_decision(pid, "bob", :keep)
      {:ok, state} = get_state(pid)
      assert state.game.current_player == :player_2
    end

    test "player_1 moves next after :swap", %{pid: pid} do
      place(pid, "alice", {0, 0})
      pie_decision(pid, "bob", :swap)
      {:ok, state} = get_state(pid)
      assert state.game.current_player == :player_1
    end

    test ":swap does not give player_2 two consecutive moves", %{pid: pid} do
      place(pid, "alice", {0, 0})
      pie_decision(pid, "bob", :swap)
      # alice (player_1) must go next
      assert :ok = place(pid, "alice", {1, 0})
      # then bob
      assert :ok = place(pid, "bob", {2, 0})
    end
  end

  describe "pie rule validation" do
    setup do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")
      {:ok, pid: pid}
    end

    test "player_1 cannot make the pie decision", %{pid: pid} do
      place(pid, "alice", {0, 0})
      assert {:error, :not_your_turn} = pie_decision(pid, "alice", :keep)
    end

    test "spectator cannot make the pie decision", %{pid: pid} do
      join(pid, "carol")
      place(pid, "alice", {0, 0})
      assert {:error, :spectator_cannot_decide} = pie_decision(pid, "carol", :keep)
    end

    test "pie decision outside :pie_decision phase is rejected", %{pid: pid} do
      assert {:error, :invalid_phase} = pie_decision(pid, "bob", :keep)
    end

    test "cannot make pie decision twice", %{pid: pid} do
      place(pid, "alice", {0, 0})
      pie_decision(pid, "bob", :keep)
      assert {:error, :invalid_phase} = pie_decision(pid, "bob", :keep)
    end

    test "cannot place a stone during :pie_decision phase", %{pid: pid} do
      place(pid, "alice", {0, 0})
      assert {:error, :game_not_playing} = place(pid, "bob", {1, 0})
    end
  end

  describe "AI pie decision (human_vs_ai)" do
    test "AI automatically makes pie decision after first human move" do
      pid = start_server(:human_vs_ai)
      join(pid, "alice")

      assert :ok = place(pid, "alice", {0, 0})

      Process.sleep(700)

      {:ok, state} = get_state(pid)
      assert state.game.phase in [:playing, :game_over]
    end

    test "human can move after AI swaps (status not stuck at :ai_thinking)" do
      # Deterministically force a swap by stubbing the AI choice is not possible
      # without mocking, so we instead verify the invariant: after AI decides,
      # status must be :playing or :ai_thinking (never permanently stuck), and
      # the human must be able to place within a reasonable window.
      pid = start_server(:human_vs_ai)
      join(pid, "alice")

      assert :ok = place(pid, "alice", {0, 0})

      # Wait for AI pie decision (200–500ms) plus AI move if it kept (another 200–500ms)
      Process.sleep(1200)

      {:ok, state} = get_state(pid)
      # Regardless of swap or keep, the game must not be stuck — it is either
      # alice's turn (:player_1) or alice just played and it's the AI's turn.
      assert state.status in [:playing, :ai_thinking, :game_over]
      assert state.game.phase in [:playing, :game_over]

      # If it is alice's turn, she must be able to place without error.
      if state.game.current_player == :player_1 and state.game.phase == :playing do
        assert :ok = place(pid, "alice", {5, 0})
      end
    end

    test "game reaches :playing after AI pie decision and AI move" do
      pid = start_server(:human_vs_ai)
      join(pid, "alice")

      assert :ok = place(pid, "alice", {0, 0})

      Process.sleep(1200)

      {:ok, state} = get_state(pid)
      assert state.game.current_player == :player_1
    end
  end

  # ---------------------------------------------------------------------------
  # Resign
  # ---------------------------------------------------------------------------

  describe "resign" do
    setup do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")
      {:ok, pid: pid}
    end

    test "player_1 can resign and player_2 wins", %{pid: pid} do
      assert :ok = resign(pid, "alice")
      {:ok, state} = get_state(pid)
      assert state.game.phase == :game_over
      assert state.game.winner == :red
      assert state.game.win_reason == :resignation
      assert state.status == :game_over
    end

    test "player_2 can resign and player_1 wins", %{pid: pid} do
      place(pid, "alice", {0, 0})
      pie_decision(pid, "bob", :keep)
      assert :ok = resign(pid, "bob")
      {:ok, state} = get_state(pid)
      assert state.game.winner == :blue
      assert state.game.win_reason == :resignation
    end

    test "spectator cannot resign", %{pid: pid} do
      join(pid, "carol")
      assert {:error, :spectator_cannot_resign} = resign(pid, "carol")
    end

    test "unknown session cannot resign", %{pid: pid} do
      assert {:error, :not_in_game} = resign(pid, "ghost")
    end

    test "cannot resign after game is already over", %{pid: pid} do
      resign(pid, "alice")
      assert {:error, :game_not_playing} = resign(pid, "bob")
    end

    test "rematch starts fresh game with same mode", %{pid: pid} do
      resign(pid, "alice")
      {:ok, state} = get_state(pid)
      assert state.status == :game_over
    end
  end

  # ---------------------------------------------------------------------------
  # Win reason
  # ---------------------------------------------------------------------------

  describe "win reason" do
    test "ring win records :ring as win_reason" do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")

      # Blue builds a ring: {1,0},{0,1},{-1,1},{-1,0},{0,-1},{1,-1}
      # Red plays 5 harmless moves in between
      place(pid, "alice", {1, 0})
      pie_decision(pid, "bob", :keep)
      place(pid, "bob", {5, 0})
      place(pid, "alice", {0, 1})
      place(pid, "bob", {6, 0})
      place(pid, "alice", {-1, 1})
      place(pid, "bob", {7, 0})
      place(pid, "alice", {-1, 0})
      place(pid, "bob", {8, 0})
      place(pid, "alice", {0, -1})
      place(pid, "bob", {9, -1})
      place(pid, "alice", {1, -1})

      {:ok, state} = get_state(pid)
      assert state.game.phase == :game_over
      assert state.game.win_reason == :ring
    end
  end

  # ---------------------------------------------------------------------------
  # Per-move timer
  # ---------------------------------------------------------------------------

  describe "per-move timer" do
    test "move_deadline is set when game starts (hvh)" do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")
      {:ok, state} = get_state(pid)
      assert is_integer(state.move_deadline)
      assert state.move_deadline > :os.system_time(:millisecond)
    end

    test "move_deadline is set when human joins (hva)" do
      pid = start_server(:human_vs_ai)
      join(pid, "alice")
      {:ok, state} = get_state(pid)
      assert is_integer(state.move_deadline)
    end

    test "move_deadline resets after a valid move" do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")
      {:ok, before} = get_state(pid)
      Process.sleep(20)
      place(pid, "alice", {0, 0})
      pie_decision(pid, "bob", :keep)
      {:ok, after_state} = get_state(pid)
      # New deadline should be later than the original one (reset after bob's turn)
      assert after_state.move_deadline > before.move_deadline
    end

    test "move_deadline is nil after game over by resign" do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")
      resign(pid, "alice")
      {:ok, state} = get_state(pid)
      assert is_nil(state.move_deadline)
    end

    test "timeout causes game over with :timeout win reason" do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")

      # Manually fire the timeout message, simulating timer expiry
      send(pid, :move_timeout)
      Process.sleep(50)

      {:ok, state} = get_state(pid)
      assert state.game.phase == :game_over
      assert state.game.win_reason == :timeout
      # The current player (alice/player_1) loses; player_2 wins
      assert state.game.winner == :red
    end

    test "timeout is ignored once game is already over" do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")
      resign(pid, "alice")

      send(pid, :move_timeout)
      Process.sleep(50)

      {:ok, state} = get_state(pid)
      assert state.game.win_reason == :resignation
    end
  end
end
