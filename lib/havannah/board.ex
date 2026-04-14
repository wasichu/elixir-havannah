defmodule Havannah.Board do
  @moduledoc """
  Board coordinate logic for Havannah using axial coordinates (q, r).

  The board is a regular hexagon with 10 cells per side (radius = 9).
  A cell {q, r} is valid when max(|q|, |r|, |q+r|) <= 9, which is
  equivalent to all three conditions: |q| <= 9, |r| <= 9, |q+r| <= 9.

  Total cells: 3 * 9^2 + 3 * 9 + 1 = 271.
  """

  @radius 9

  @doc "Returns the board radius (size - 1)."
  def radius, do: @radius

  @doc "Returns true if the given axial coordinate {q, r} is a valid board cell."
  def valid?({q, r}) do
    abs(q) <= @radius and abs(r) <= @radius and abs(q + r) <= @radius
  end

  @doc "Generates all valid board cells as a list of {q, r} tuples."
  def cells do
    for q <- -@radius..@radius,
        r <- -@radius..@radius,
        valid?({q, r}),
        do: {q, r}
  end

  @doc """
  Returns the up-to-6 valid neighbors of a given cell.
  Cells on the board edge will have fewer than 6 neighbors.
  """
  def neighbors({q, r}) do
    [
      {q + 1, r},
      {q - 1, r},
      {q, r + 1},
      {q, r - 1},
      {q + 1, r - 1},
      {q - 1, r + 1}
    ]
    |> Enum.filter(&valid?/1)
  end

  @doc "Returns an empty board as a map from {q, r} => nil for every valid cell."
  def new_board do
    Map.new(cells(), fn cell -> {cell, nil} end)
  end
end
