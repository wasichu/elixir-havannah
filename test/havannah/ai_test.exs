defmodule Havannah.AITest do
  use ExUnit.Case, async: true

  alias Havannah.{AI, Game}

  describe "random_move/1" do
    test "returns a valid empty cell" do
      game = Game.new(:player_1, :player_2)
      {:ok, cell} = AI.random_move(game)
      assert is_nil(game.board[cell]), "chosen cell must be empty"
    end

    test "returned cell is on the board" do
      game = Game.new(:player_1, :player_2)
      {:ok, cell} = AI.random_move(game)
      assert Map.has_key?(game.board, cell)
    end

    test "returns :no_moves when board is full" do
      # Fill the entire board with blue stones directly
      game = Game.new(:player_1, :player_2)
      full_board = Map.new(game.board, fn {cell, _} -> {cell, :blue} end)
      full_game = %{game | board: full_board}
      assert {:error, :no_moves} = AI.random_move(full_game)
    end

    test "only picks from empty cells" do
      game = Game.new(:player_1, :player_2)
      # Place a few stones so the board is partially filled
      {:ok, game} = Game.place(game, {0, 0})
      {:ok, game} = Game.pie_decision(game, :keep)
      {:ok, game} = Game.place(game, {1, 0})
      {:ok, game} = Game.place(game, {0, 1})

      occupied = [{0, 0}, {1, 0}, {0, 1}]

      for _ <- 1..20 do
        {:ok, cell} = AI.random_move(game)
        refute cell in occupied, "AI must not pick an occupied cell"
      end
    end
  end
end
