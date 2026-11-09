defmodule Havannah.GameServerTest do
  use ExUnit.Case, async: true

  alias Havannah.GameServer

  # Start a GameServer directly via pid for isolated, async-safe tests.
  # The public API (GameServer.join/place/get_state) goes through Registry,
  # so we call GenServer directly here.
  defp start_server(mode) do
    game_id = "test-#{System.unique_integer([:positive])}"

    start_supervised!(%{
      id: game_id,
      start: {GenServer, :start_link, [GameServer, {game_id, mode, [ai_delay_ms: 60_000]}]}
    })
  end

  defp fire_ai(pid) do
    state = :sys.get_state(pid)
    send(pid, {:timeout, state.ai_ref, :ai_move})
    get_state(pid)
  end

  defp finish_ai_turn(pid) do
    {:ok, state} = fire_ai(pid)
    if state.status == :ai_thinking, do: fire_ai(pid), else: {:ok, state}
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

      fire_ai(pid)

      {:ok, state} = get_state(pid)
      assert state.game.phase in [:playing, :game_over]
    end

    test "human can move after AI finishes its opening turn" do
      pid = start_server(:human_vs_ai)
      join(pid, "alice")

      assert :ok = place(pid, "alice", {0, 0})

      finish_ai_turn(pid)

      {:ok, state} = get_state(pid)
      assert state.status == :playing
      assert state.game.phase == :playing
      assert state.game.current_player == :player_1
      {cell, nil} = Enum.find(state.game.board, fn {_cell, side} -> is_nil(side) end)
      assert :ok = place(pid, "alice", cell)
    end

    test "game reaches :playing after AI pie decision and AI move" do
      pid = start_server(:human_vs_ai)
      join(pid, "alice")

      assert :ok = place(pid, "alice", {0, 0})

      finish_ai_turn(pid)

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
      old_ref = :sys.get_state(pid).timer_ref
      place(pid, "alice", {0, 0})
      pie_decision(pid, "bob", :keep)
      {:ok, after_state} = get_state(pid)
      assert after_state.move_deadline >= before.move_deadline
      refute :sys.get_state(pid).timer_ref == old_ref
      assert Process.read_timer(old_ref) == false
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
      state = :sys.get_state(pid)
      send(pid, {:timeout, state.timer_ref || make_ref(), :move_timeout})

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

      state = :sys.get_state(pid)
      send(pid, {:timeout, state.timer_ref || make_ref(), :move_timeout})

      {:ok, state} = get_state(pid)
      assert state.game.win_reason == :resignation
    end
  end

  describe "turn and identity safety" do
    test "cannot move before both human slots are filled" do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      assert {:error, :waiting_for_players} = place(pid, "alice", {0, 0})
      {:ok, state} = get_state(pid)
      assert state.game.phase == :opening
      assert is_nil(state.move_deadline)
    end

    test "snapshots and broadcasts conceal session identities" do
      pid = start_server(:human_vs_human)
      state = :sys.get_state(pid)
      Phoenix.PubSub.subscribe(Havannah.PubSub, "game:#{state.id}")
      join(pid, "private-alice-session")
      assert_receive {:game_updated, snapshot}
      assert snapshot.slots.player_1 == :occupied
      refute Map.has_key?(snapshot, :assignments)
      assert {:ok, ^snapshot} = get_state(pid)
    end

    test "cancelled timeout cannot end the next turn" do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")
      old_ref = :sys.get_state(pid).timer_ref
      place(pid, "alice", {0, 0})
      send(pid, {:timeout, old_ref, :move_timeout})
      {:ok, state} = get_state(pid)
      assert state.game.phase == :pie_decision
      assert state.status == :playing
    end

    test "stale AI messages cannot advance a subsequent AI turn" do
      pid = start_server(:human_vs_ai)
      join(pid, "alice")
      place(pid, "alice", {0, 0})
      old_ref = :sys.get_state(pid).ai_ref
      finish_ai_turn(pid)
      {:ok, state} = get_state(pid)
      {cell, nil} = Enum.find(state.game.board, fn {_cell, side} -> is_nil(side) end)
      place(pid, "alice", cell)
      {:ok, before} = get_state(pid)
      send(pid, {:timeout, old_ref, :ai_move})
      assert {:ok, ^before} = get_state(pid)
    end

    test "malformed coordinates do not crash the game process" do
      pid = start_server(:human_vs_human)
      join(pid, "alice")
      join(pid, "bob")

      for cell <- [{"0", 0}, {0.5, 0}, nil, [0, 0]] do
        assert {:error, :invalid_cell} = place(pid, "alice", cell)
      end

      assert Process.alive?(pid)
    end

    test "a crashed supervised match is not restarted with an empty board" do
      {:ok, id} = Havannah.GameSupervisor.start_game(:human_vs_human)
      [{pid, _}] = Registry.lookup(Havannah.GameRegistry, id)
      monitor = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^pid, :killed}
      assert {:error, :not_found} = GameServer.get_state(id)
    end

    test "public API returns not_found for missing games" do
      assert {:error, :not_found} = GameServer.get_state("missing")
      assert {:error, :not_found} = GameServer.join("missing", "alice")
    end
  end
end
