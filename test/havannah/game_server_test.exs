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
end
