defmodule Havannah.BoardTest do
  use ExUnit.Case, async: true

  alias Havannah.Board

  describe "valid?/1" do
    test "center cell is valid" do
      assert Board.valid?({0, 0})
    end

    test "all six corners of the hexagon are valid" do
      assert Board.valid?({9, 0})
      assert Board.valid?({0, 9})
      assert Board.valid?({-9, 0})
      assert Board.valid?({0, -9})
      assert Board.valid?({9, -9})
      assert Board.valid?({-9, 9})
    end

    test "cells just outside the board are invalid" do
      refute Board.valid?({10, 0})
      refute Board.valid?({0, 10})
      refute Board.valid?({-10, 0})
      refute Board.valid?({0, -10})
      # |q+r| = 10 violates the diagonal constraint
      refute Board.valid?({5, 5})
      refute Board.valid?({-5, -5})
    end
  end

  describe "cells/0" do
    test "returns 271 cells for a size-10 board" do
      # Formula: 3*R^2 + 3*R + 1 = 3*81 + 27 + 1 = 271
      assert length(Board.cells()) == 271
    end

    test "all returned cells are valid" do
      assert Enum.all?(Board.cells(), &Board.valid?/1)
    end

    test "contains no duplicates" do
      cells = Board.cells()
      assert length(cells) == length(Enum.uniq(cells))
    end
  end

  describe "neighbors/1" do
    test "center cell has 6 neighbors" do
      assert length(Board.neighbors({0, 0})) == 6
    end

    test "corner cell has 3 neighbors" do
      # Corner (9, 0): three of its six axial neighbors fall outside the board
      assert length(Board.neighbors({9, 0})) == 3
    end

    test "all returned neighbors are valid cells" do
      assert Enum.all?(Board.neighbors({3, -2}), &Board.valid?/1)
    end

    test "neighbor relationship is symmetric" do
      cell = {3, -2}

      for neighbor <- Board.neighbors(cell) do
        assert cell in Board.neighbors(neighbor),
               "Expected #{inspect(cell)} to be a neighbor of #{inspect(neighbor)}"
      end
    end

    test "returns at most 6 neighbors" do
      assert length(Board.neighbors({0, 0})) <= 6
      assert length(Board.neighbors({9, 0})) <= 6
    end
  end

  describe "new_board/0" do
    test "contains 271 cells" do
      assert map_size(Board.new_board()) == 271
    end

    test "all cells start empty (nil)" do
      assert Enum.all?(Board.new_board(), fn {_cell, side} -> is_nil(side) end)
    end

    test "all keys are valid cells" do
      assert Enum.all?(Board.new_board(), fn {cell, _side} -> Board.valid?(cell) end)
    end
  end
end
