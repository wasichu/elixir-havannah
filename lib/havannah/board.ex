defmodule Havannah.Board do
  @moduledoc """
  Board coordinate logic for Havannah using axial coordinates (q, r).

  The board is a regular hexagon with 10 cells per side (radius = 9).
  A cell {q, r} is valid when max(|q|, |r|, |q+r|) <= 9, which is
  equivalent to all three conditions: |q| <= 9, |r| <= 9, |q+r| <= 9.

  Total cells: 3 * 9^2 + 3 * 9 + 1 = 271.
  """

  @type cell :: {integer(), integer()}
  @type t :: %{cell() => :blue | :red | nil}

  @radius 9

  @doc "Returns the board radius (size - 1)."
  @spec radius() :: pos_integer()
  def radius, do: @radius

  @doc "Returns true if the given axial coordinate {q, r} is a valid board cell."
  @spec valid?(term()) :: boolean()
  def valid?({q, r}) when is_integer(q) and is_integer(r) do
    abs(q) <= @radius and abs(r) <= @radius and abs(q + r) <= @radius
  end

  def valid?(_), do: false

  @doc "Generates all valid board cells as a list of {q, r} tuples."
  @spec cells() :: [cell()]
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
  @spec neighbors(cell()) :: [cell()]
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
  @spec new_board() :: t()
  def new_board do
    Map.new(cells(), fn cell -> {cell, nil} end)
  end
end
