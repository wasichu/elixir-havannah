defmodule Havannah.AI do
  @moduledoc "Simple random AI for Havannah. Picks a random legal move."

  alias Havannah.Game

  @doc """
  Returns a random empty cell from the current game board.
  Returns {:ok, {q, r}} or {:error, :no_moves} if the board is full.
  """
  @spec random_move(%Game{}) :: {:ok, {integer(), integer()}} | {:error, :no_moves}
  def random_move(%Game{board: board}) do
    empty = for {cell, nil} <- board, do: cell

    case empty do
      [] -> {:error, :no_moves}
      cells -> {:ok, Enum.random(cells)}
    end
  end
end
