defmodule Havannah.Game do
  @moduledoc """
  Game state for a Havannah match.

  The board stores side ownership (:blue or :red), decoupled from player
  identity. Players are mapped to sides via the `sides` field. This design
  supports a future pie rule where the second player can swap sides after
  the first move, without changing board state.
  """

  alias Havannah.{Board, Rules}

  @enforce_keys [:board, :players, :sides, :current_player, :phase]
  defstruct [:board, :players, :sides, :current_player, :phase, :last_move, :winner]

  @type side :: :blue | :red
  @type player :: any()
  @type t :: %__MODULE__{
          board: %{{integer(), integer()} => side() | nil},
          players: [player()],
          sides: %{player() => side()},
          current_player: player(),
          phase: :playing | :game_over,
          last_move: {integer(), integer()} | nil,
          winner: side() | nil
        }

  @doc """
  Creates a new game with two players. Player `player_a` is assigned :blue
  and goes first; `player_b` is assigned :red.
  """
  def new(player_a, player_b) do
    %__MODULE__{
      board: Board.new_board(),
      players: [player_a, player_b],
      sides: %{player_a => :blue, player_b => :red},
      current_player: player_a,
      phase: :playing,
      last_move: nil,
      winner: nil
    }
  end

  @doc "Returns the side (:blue or :red) for the given player."
  def player_side(%__MODULE__{sides: sides}, player) do
    Map.get(sides, player)
  end

  @doc """
  Places a stone for the current player on cell {q, r}.
  Returns {:ok, updated_game} | {:error, reason}.

  After a successful placement, win conditions are evaluated. If the current
  player wins, the game transitions to :game_over and no further moves are
  accepted.
  """
  def place(%__MODULE__{phase: :playing} = game, {q, r}) do
    cond do
      not Board.valid?({q, r}) ->
        {:error, :invalid_cell}

      Map.get(game.board, {q, r}) != nil ->
        {:error, :cell_occupied}

      true ->
        side = player_side(game, game.current_player)
        new_board = Map.put(game.board, {q, r}, side)

        case Rules.check_win(new_board, side) do
          :none ->
            next = next_player(game)
            {:ok, %{game | board: new_board, current_player: next, last_move: {q, r}}}

          _win ->
            {:ok, %{game | board: new_board, phase: :game_over, winner: side, last_move: {q, r}}}
        end
    end
  end

  def place(%__MODULE__{}, _), do: {:error, :game_not_playing}

  defp next_player(%__MODULE__{players: [p1, p2], current_player: current}) do
    if current == p1, do: p2, else: p1
  end
end
