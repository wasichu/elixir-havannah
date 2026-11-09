defmodule Havannah.Rules do
  @moduledoc """
  Pure win detection logic for Havannah.

  Three win conditions are checked after each move:
  - Bridge: a connected group touches two distinct corners
  - Fork:   a connected group touches three distinct edges
  - Ring:   the player's stones completely enclose one or more cells
  """

  alias Havannah.Board

  @radius Board.radius()

  # Six corners of the board: each lies at the intersection of two boundary constraints.
  @corners MapSet.new([
             {@radius, 0},
             {0, @radius},
             {-@radius, @radius},
             {-@radius, 0},
             {0, -@radius},
             {@radius, -@radius}
           ])

  @doc "Returns the MapSet of all six corner coordinates."
  @spec corners() :: MapSet.t(Board.cell())
  def corners, do: @corners

  @doc "Returns true if the coordinate is a corner of the board."
  @spec corner?(Board.cell()) :: boolean()
  def corner?(coord), do: MapSet.member?(@corners, coord)

  @doc """
  Returns the edge identifier (1–6) for a boundary cell that is not a corner,
  or nil for corners and interior cells.

  Edge layout (clockwise from top-right):
    1: q+r =  R  (NE edge, between corners {R,0} and {0,R})
    2: r   =  R  (SE edge, between corners {0,R} and {-R,R})
    3: q   = -R  (SW edge, between corners {-R,R} and {-R,0})
    4: q+r = -R  (NW edge, between corners {-R,0} and {0,-R})
    5: r   = -R  (NW edge, between corners {0,-R} and {R,-R})
    6: q   =  R  (E  edge, between corners {R,-R} and {R,0})
  """
  @spec edge_id(Board.cell()) :: 1..6 | nil
  def edge_id({q, r} = coord) do
    cond do
      corner?(coord) -> nil
      q + r == @radius -> 1
      r == @radius -> 2
      q == -@radius -> 3
      q + r == -@radius -> 4
      r == -@radius -> 5
      q == @radius -> 6
      true -> nil
    end
  end

  @doc """
  Returns a MapSet of all coordinates in the connected group containing `start`.
  All cells in the group share the same side as `start`.
  """
  @spec get_group(Board.t(), Board.cell()) :: MapSet.t(Board.cell())
  def get_group(board, start) do
    case Map.get(board, start) do
      nil -> MapSet.new()
      side -> collect_group([start], MapSet.new([start]), board, side)
    end
  end

  @doc """
  Checks whether `side` has won on the given board.
  Returns :bridge, :fork, :ring, or :none.
  """
  @spec check_win(Board.t(), :blue | :red) :: :bridge | :fork | :ring | :none
  def check_win(board, side) do
    groups = connected_groups(board, side)

    cond do
      Enum.any?(groups, &bridge?/1) -> :bridge
      Enum.any?(groups, &fork?/1) -> :fork
      ring?(board, side) -> :ring
      true -> :none
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp connected_groups(board, side) do
    cells =
      board
      |> Enum.filter(fn {_coord, v} -> v == side end)
      |> Enum.map(&elem(&1, 0))

    {groups, _visited} =
      Enum.reduce(cells, {[], MapSet.new()}, fn cell, {groups, visited} ->
        if MapSet.member?(visited, cell) do
          {groups, visited}
        else
          group = get_group(board, cell)
          {[group | groups], MapSet.union(visited, group)}
        end
      end)

    groups
  end

  defp collect_group([], visited, _board, _side), do: visited

  defp collect_group([cell | rest], visited, board, side) do
    new_neighbors =
      Board.neighbors(cell)
      |> Enum.filter(fn n ->
        Map.get(board, n) == side and not MapSet.member?(visited, n)
      end)

    collect_group(
      new_neighbors ++ rest,
      Enum.reduce(new_neighbors, visited, &MapSet.put(&2, &1)),
      board,
      side
    )
  end

  defp bridge?(group) do
    Enum.count(@corners, &MapSet.member?(group, &1)) >= 2
  end

  defp fork?(group) do
    group
    |> MapSet.to_list()
    |> Enum.map(&edge_id/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> length()
    |> Kernel.>=(3)
  end

  # Flood fill from all passable boundary cells.
  # Any passable cell that cannot be reached is enclosed by the player's ring.
  defp ring?(board, side) do
    passable =
      board
      |> Enum.filter(fn {_coord, v} -> v != side end)
      |> Enum.map(&elem(&1, 0))
      |> MapSet.new()

    boundary_start =
      passable
      |> Enum.filter(fn cell -> length(Board.neighbors(cell)) < 6 end)

    reachable = flood_fill(boundary_start, MapSet.new(boundary_start), passable)

    MapSet.size(passable) > MapSet.size(reachable) or filled_ring?(board, side)
  end

  # Flood fill detects empty/opponent interiors. An interior containing only
  # friendly stones still wins: one of those stones has six friendly neighbors.
  defp filled_ring?(board, side) do
    Enum.any?(board, fn {cell, owner} ->
      neighbors = Board.neighbors(cell)

      owner == side and length(neighbors) == 6 and
        Enum.all?(neighbors, &(Map.get(board, &1) == side))
    end)
  end

  defp flood_fill([], visited, _passable), do: visited

  defp flood_fill([cell | rest], visited, passable) do
    new_neighbors =
      Board.neighbors(cell)
      |> Enum.filter(fn n ->
        MapSet.member?(passable, n) and not MapSet.member?(visited, n)
      end)

    flood_fill(
      new_neighbors ++ rest,
      Enum.reduce(new_neighbors, visited, &MapSet.put(&2, &1)),
      passable
    )
  end
end
