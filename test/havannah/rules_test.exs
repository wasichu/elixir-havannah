defmodule Havannah.RulesTest do
  use ExUnit.Case, async: true

  alias Havannah.{Board, Rules}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp empty_board, do: Board.new_board()

  defp put_stones(board, side, coords) do
    Enum.reduce(coords, board, fn coord, b -> Map.put(b, coord, side) end)
  end

  # ---------------------------------------------------------------------------
  # Step 1: Connected groups
  # ---------------------------------------------------------------------------

  describe "get_group/2" do
    test "single stone returns a singleton MapSet" do
      board = put_stones(empty_board(), :blue, [{0, 0}])
      assert Rules.get_group(board, {0, 0}) == MapSet.new([{0, 0}])
    end

    test "returns all stones in a connected group" do
      coords = [{0, 0}, {1, 0}, {2, 0}]
      board = put_stones(empty_board(), :blue, coords)
      assert Rules.get_group(board, {0, 0}) == MapSet.new(coords)
    end

    test "does not bleed into a disconnected group of the same side" do
      # Two isolated blue stones with a gap between them
      board =
        empty_board()
        |> put_stones(:blue, [{0, 0}])
        |> put_stones(:blue, [{5, 0}])

      group = Rules.get_group(board, {0, 0})
      assert MapSet.member?(group, {0, 0})
      refute MapSet.member?(group, {5, 0})
    end

    test "does not cross into opponent stones" do
      board =
        empty_board()
        |> put_stones(:blue, [{0, 0}, {1, 0}])
        |> put_stones(:red, [{2, 0}])

      group = Rules.get_group(board, {0, 0})
      assert group == MapSet.new([{0, 0}, {1, 0}])
    end

    test "collects a large connected group" do
      # Diagonal chain: {0,0} → {1,-1} → {2,-2} (each is a valid neighbor)
      coords = [{0, 0}, {1, -1}, {2, -2}, {3, -3}]
      board = put_stones(empty_board(), :red, coords)
      assert Rules.get_group(board, {0, 0}) == MapSet.new(coords)
    end
  end

  # ---------------------------------------------------------------------------
  # Step 2: Board classification — corners and edges
  # ---------------------------------------------------------------------------

  describe "corner?/1" do
    test "all six corners return true" do
      for coord <- [{9, 0}, {0, 9}, {-9, 9}, {-9, 0}, {0, -9}, {9, -9}] do
        assert Rules.corner?(coord), "Expected #{inspect(coord)} to be a corner"
      end
    end

    test "interior cells are not corners" do
      refute Rules.corner?({0, 0})
      refute Rules.corner?({3, -2})
    end

    test "non-corner boundary cells are not corners" do
      refute Rules.corner?({5, 4})
      refute Rules.corner?({-9, 4})
    end
  end

  describe "edge_id/1" do
    test "corners return nil" do
      for coord <- [{9, 0}, {0, 9}, {-9, 9}, {-9, 0}, {0, -9}, {9, -9}] do
        assert is_nil(Rules.edge_id(coord)), "Expected #{inspect(coord)} to have nil edge_id"
      end
    end

    test "interior cells return nil" do
      assert is_nil(Rules.edge_id({0, 0}))
      assert is_nil(Rules.edge_id({3, -2}))
    end

    test "edge 1 cells (q+r = 9, excluding corners)" do
      assert Rules.edge_id({5, 4}) == 1
      assert Rules.edge_id({1, 8}) == 1
      assert Rules.edge_id({8, 1}) == 1
    end

    test "edge 2 cells (r = 9, excluding corners)" do
      assert Rules.edge_id({-1, 9}) == 2
      assert Rules.edge_id({-5, 9}) == 2
      assert Rules.edge_id({-8, 9}) == 2
    end

    test "edge 3 cells (q = -9, excluding corners)" do
      assert Rules.edge_id({-9, 1}) == 3
      assert Rules.edge_id({-9, 5}) == 3
      assert Rules.edge_id({-9, 8}) == 3
    end

    test "edge 4 cells (q+r = -9, excluding corners)" do
      assert Rules.edge_id({-5, -4}) == 4
      assert Rules.edge_id({-1, -8}) == 4
      assert Rules.edge_id({-8, -1}) == 4
    end

    test "edge 5 cells (r = -9, excluding corners)" do
      assert Rules.edge_id({1, -9}) == 5
      assert Rules.edge_id({5, -9}) == 5
      assert Rules.edge_id({8, -9}) == 5
    end

    test "edge 6 cells (q = 9, excluding corners)" do
      assert Rules.edge_id({9, -1}) == 6
      assert Rules.edge_id({9, -5}) == 6
      assert Rules.edge_id({9, -8}) == 6
    end

    test "each non-corner boundary cell belongs to exactly one edge" do
      Board.cells()
      |> Enum.filter(fn cell -> length(Board.neighbors(cell)) < 6 end)
      |> Enum.reject(&Rules.corner?/1)
      |> Enum.each(fn cell ->
        id = Rules.edge_id(cell)
        assert id in 1..6, "Expected #{inspect(cell)} to have an edge id 1-6, got #{inspect(id)}"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Step 3: Bridge detection
  # ---------------------------------------------------------------------------

  describe "check_win/2 — bridge" do
    test "connecting two corners wins by bridge" do
      # Path along edge 1 from corner {9,0} to corner {0,9}
      path = for q <- 0..9, do: {q, 9 - q}
      board = put_stones(empty_board(), :blue, path)
      assert Rules.check_win(board, :blue) == :bridge
    end

    test "path from corner to corner on opposite side wins by bridge" do
      # Corner {9,0} to corner {-9,0}: straight horizontal path
      path = for q <- -9..9, do: {q, 0}
      board = put_stones(empty_board(), :blue, path)
      assert Rules.check_win(board, :blue) == :bridge
    end

    test "single corner does not win" do
      board = put_stones(empty_board(), :blue, [{9, 0}])
      assert Rules.check_win(board, :blue) == :none
    end

    test "two disconnected corners do not win (not connected)" do
      board = put_stones(empty_board(), :blue, [{9, 0}, {0, 9}])
      # They are not connected — no path between them
      assert Rules.check_win(board, :blue) == :none
    end

    test "opponent having a bridge does not count for current player" do
      path = for q <- 0..9, do: {q, 9 - q}
      board = put_stones(empty_board(), :red, path)
      assert Rules.check_win(board, :blue) == :none
    end
  end

  # ---------------------------------------------------------------------------
  # Step 4: Fork detection
  # ---------------------------------------------------------------------------

  describe "check_win/2 — fork" do
    test "group touching three distinct edges wins by fork" do
      # Vertical bar on q=4 from edge 5 (r=-9) through edge 1 (q+r=9, so r=5)
      bar = for r <- -9..5, do: {4, r}

      # Branch from {4, 0} diagonally to edge 2 (r=9): {4,0}→{3,1}→...→{-5,9}
      branch = for i <- 0..9, do: {4 - i, i}

      all_coords = Enum.uniq(bar ++ branch)
      board = put_stones(empty_board(), :blue, all_coords)
      assert Rules.check_win(board, :blue) == :fork
    end

    test "group touching only two edges does not win" do
      # Short path from edge 5 to edge 1, no third edge
      # {4,-9} up to {4,5} (q+r=9) — only edges 5 and 1
      path = for r <- -9..5, do: {4, r}
      board = put_stones(empty_board(), :blue, path)
      assert Rules.check_win(board, :blue) == :none
    end

    test "group touching three edges but disconnected does not win" do
      # Three isolated edge cells, one per edge — not connected
      board =
        empty_board()
        |> put_stones(:blue, [{5, 4}])
        |> put_stones(:blue, [{-9, 4}])
        |> put_stones(:blue, [{5, -9}])

      assert Rules.check_win(board, :blue) == :none
    end
  end

  # ---------------------------------------------------------------------------
  # Step 5: Ring detection
  # ---------------------------------------------------------------------------

  describe "check_win/2 — ring" do
    test "six stones forming a ring around the center win by ring" do
      # Minimal hexagonal ring surrounding {0,0}
      ring = [{1, 0}, {0, 1}, {-1, 1}, {-1, 0}, {0, -1}, {1, -1}]
      board = put_stones(empty_board(), :blue, ring)
      assert Rules.check_win(board, :blue) == :ring
    end

    test "ring enclosing empty space wins" do
      # Larger ring — encloses several empty cells
      # Ring of radius-2 hex: the 12 cells surrounding the inner hex of 7
      outer_ring = [
        {2, 0},
        {2, -1},
        {2, -2},
        {1, -2},
        {0, -2},
        {-1, -1},
        {-2, 0},
        {-2, 1},
        {-2, 2},
        {-1, 2},
        {0, 2},
        {1, 1}
      ]

      board = put_stones(empty_board(), :blue, outer_ring)
      assert Rules.check_win(board, :blue) == :ring
    end

    test "ring enclosing opponent stones wins" do
      ring = [{1, 0}, {0, 1}, {-1, 1}, {-1, 0}, {0, -1}, {1, -1}]

      board =
        empty_board()
        |> put_stones(:blue, ring)
        |> put_stones(:red, [{0, 0}])

      assert Rules.check_win(board, :blue) == :ring
    end

    test "open C-shape (one gap in the ring) does not win" do
      # Remove one stone from the ring so it is not closed
      open_ring = [{1, 0}, {0, 1}, {-1, 1}, {-1, 0}, {0, -1}]
      board = put_stones(empty_board(), :blue, open_ring)
      assert Rules.check_win(board, :blue) == :none
    end

    test "chain of stones with no enclosed region does not win" do
      # Straight line — no area enclosed
      path = for q <- -5..5, do: {q, 0}
      board = put_stones(empty_board(), :blue, path)
      assert Rules.check_win(board, :blue) == :none
    end

    test "arc touching the board boundary does not enclose any board cell" do
      # Stones along the boundary edge 6 and connected interior, but no closed loop
      arc = [{9, -1}, {9, -2}, {9, -3}, {9, -4}, {8, -4}, {7, -4}]
      board = put_stones(empty_board(), :blue, arc)
      assert Rules.check_win(board, :blue) == :none
    end

    test "empty board has no ring" do
      assert Rules.check_win(empty_board(), :blue) == :none
    end

    test "opponent ring does not count for the other player" do
      ring = [{1, 0}, {0, 1}, {-1, 1}, {-1, 0}, {0, -1}, {1, -1}]
      board = put_stones(empty_board(), :red, ring)
      assert Rules.check_win(board, :blue) == :none
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: full move sequences
  # ---------------------------------------------------------------------------

  describe "check_win/2 — full board scenarios" do
    test "returns :none on an empty board for either side" do
      assert Rules.check_win(empty_board(), :blue) == :none
      assert Rules.check_win(empty_board(), :red) == :none
    end

    test "only the winning side is detected" do
      ring = [{1, 0}, {0, 1}, {-1, 1}, {-1, 0}, {0, -1}, {1, -1}]
      board = put_stones(empty_board(), :blue, ring)
      assert Rules.check_win(board, :blue) == :ring
      assert Rules.check_win(board, :red) == :none
    end
  end
end
