defmodule Havannah.GameTest do
  use ExUnit.Case, async: true

  alias Havannah.Game

  setup do
    {:ok, game: Game.new(:player_1, :player_2)}
  end

  describe "new/2" do
    test "creates a game in :playing phase", %{game: game} do
      assert game.phase == :playing
    end

    test "player_1 goes first", %{game: game} do
      assert game.current_player == :player_1
    end

    test "player_1 is assigned :blue", %{game: game} do
      assert Game.player_side(game, :player_1) == :blue
    end

    test "player_2 is assigned :red", %{game: game} do
      assert Game.player_side(game, :player_2) == :red
    end

    test "board starts completely empty", %{game: game} do
      assert Enum.all?(game.board, fn {_cell, side} -> is_nil(side) end)
    end

    test "last_move starts as nil", %{game: game} do
      assert is_nil(game.last_move)
    end
  end

  describe "place/2" do
    test "places a blue stone for player_1", %{game: game} do
      {:ok, new_game} = Game.place(game, {0, 0})
      assert new_game.board[{0, 0}] == :blue
    end

    test "places a red stone for player_2", %{game: game} do
      {:ok, game} = Game.place(game, {0, 0})
      {:ok, game} = Game.place(game, {1, 0})
      assert game.board[{1, 0}] == :red
    end

    test "alternates turns: player_1 → player_2 → player_1", %{game: game} do
      assert game.current_player == :player_1

      {:ok, game} = Game.place(game, {0, 0})
      assert game.current_player == :player_2

      {:ok, game} = Game.place(game, {1, 0})
      assert game.current_player == :player_1
    end

    test "records the last move coordinate", %{game: game} do
      {:ok, new_game} = Game.place(game, {2, -1})
      assert new_game.last_move == {2, -1}
    end

    test "last_move updates on each placement", %{game: game} do
      {:ok, game} = Game.place(game, {0, 0})
      {:ok, game} = Game.place(game, {3, -2})
      assert game.last_move == {3, -2}
    end

    test "returns :cell_occupied error when cell is taken", %{game: game} do
      {:ok, game} = Game.place(game, {0, 0})
      assert {:error, :cell_occupied} = Game.place(game, {0, 0})
    end

    test "returns :invalid_cell error for out-of-bounds coordinates", %{game: game} do
      assert {:error, :invalid_cell} = Game.place(game, {10, 0})
      assert {:error, :invalid_cell} = Game.place(game, {5, 5})
      assert {:error, :invalid_cell} = Game.place(game, {-10, 0})
    end

    test "occupied cell does not change owner after failed placement", %{game: game} do
      {:ok, game} = Game.place(game, {0, 0})
      {:error, _} = Game.place(game, {0, 0})
      assert game.board[{0, 0}] == :blue
    end

    test "can place on any valid board cell", %{game: game} do
      {:ok, game} = Game.place(game, {9, 0})
      assert game.board[{9, 0}] == :blue

      {:ok, game} = Game.place(game, {-9, 9})
      assert game.board[{-9, 9}] == :red
    end
  end

  describe "win detection" do
    test "game starts in :playing phase with no winner", %{game: game} do
      assert game.phase == :playing
      assert is_nil(game.winner)
    end

    test "bridge win transitions to :game_over and records winner" do
      game = Game.new(:player_1, :player_2)
      # Blue builds a bridge along edge 1 (q+r=9): 10 cells from {0,9} to {9,0}
      bridge_path = for q <- 0..9, do: {q, 9 - q}
      # Red plays 9 harmless moves (game ends after blue's 10th placement)
      red_cells = [{-1, -1}, {-2, -1}, {-3, -1}, {-4, -1}, {-5, -1}, {-1, -2}, {-2, -2}, {-3, -2}, {-4, -2}]

      game =
        Enum.zip_with(bridge_path, red_cells ++ [nil], fn blue_cell, red_cell ->
          {blue_cell, red_cell}
        end)
        |> Enum.reduce(game, fn {blue_cell, red_cell}, g ->
          {:ok, g} = Game.place(g, blue_cell)

          if g.phase == :playing and red_cell do
            {:ok, g} = Game.place(g, red_cell)
            g
          else
            g
          end
        end)

      assert game.phase == :game_over
      assert game.winner == :blue
    end

    test "after game over, further placements are rejected" do
      game = Game.new(:player_1, :player_2)
      ring = [{1, 0}, {0, 1}, {-1, 1}, {-1, 0}, {0, -1}, {1, -1}]
      # Red plays 5 harmless moves while blue builds the ring; game ends on blue's 6th
      red_cells = [{5, 0}, {6, 0}, {7, 0}, {8, 0}, {9, -1}]

      game =
        Enum.zip_with(ring, red_cells ++ [nil], fn b, r -> {b, r} end)
        |> Enum.reduce(game, fn {blue_cell, red_cell}, g ->
          {:ok, g} = Game.place(g, blue_cell)

          if g.phase == :playing and red_cell do
            {:ok, g} = Game.place(g, red_cell)
            g
          else
            g
          end
        end)

      assert game.phase == :game_over
      assert {:error, :game_not_playing} = Game.place(game, {0, 0})
    end

    test "ring win: blue enclosing the center wins" do
      game = Game.new(:player_1, :player_2)
      ring = [{1, 0}, {0, 1}, {-1, 1}, {-1, 0}, {0, -1}, {1, -1}]
      red_cells = [{5, 0}, {6, 0}, {7, 0}, {8, 0}, {9, -1}]

      game =
        Enum.zip_with(ring, red_cells ++ [nil], fn b, r -> {b, r} end)
        |> Enum.reduce(game, fn {blue_cell, red_cell}, g ->
          {:ok, g} = Game.place(g, blue_cell)

          if g.phase == :playing and red_cell do
            {:ok, g} = Game.place(g, red_cell)
            g
          else
            g
          end
        end)

      assert game.phase == :game_over
      assert game.winner == :blue
    end
  end
end
