defmodule Havannah.Game do
  @moduledoc """
  Game state for a Havannah match.

  The board stores side ownership (:blue or :red), decoupled from player
  identity. Players are mapped to sides via the `sides` field. This design
  supports the pie rule where the second player can swap sides after the first
  move without changing board state.
  """

  alias Havannah.{Board, Rules}

  @enforce_keys [:board, :players, :sides, :current_player, :phase]
  defstruct [:board, :players, :sides, :current_player, :phase, :last_move, :winner, :win_reason]

  @type side :: :blue | :red
  @type player :: term()
  @type phase :: :opening | :pie_decision | :playing | :game_over
  @type win_reason :: :bridge | :fork | :ring | :resignation | :timeout
  @type t :: %__MODULE__{
          board: Board.t(),
          players: [player()],
          sides: %{player() => side()},
          current_player: player(),
          phase: phase(),
          last_move: {integer(), integer()} | nil,
          winner: side() | nil,
          win_reason: win_reason() | nil
        }

  @doc """
  Creates a new game with two players. Player `player_a` is assigned :blue
  and goes first; `player_b` is assigned :red.
  """
  @spec new(player(), player()) :: t()
  def new(player_a, player_b) do
    %__MODULE__{
      board: Board.new_board(),
      players: [player_a, player_b],
      sides: %{player_a => :blue, player_b => :red},
      current_player: player_a,
      phase: :opening,
      last_move: nil,
      winner: nil,
      win_reason: nil
    }
  end

  @doc "Returns the side (:blue or :red) for the given player."
  @spec player_side(t(), player()) :: side() | nil
  def player_side(%__MODULE__{sides: sides}, player) do
    Map.get(sides, player)
  end

  @doc """
  Places a stone for the current player on cell {q, r}.
  Returns {:ok, updated_game} | {:error, reason}.

  Valid in :opening and :playing phases. After a successful placement in
  :opening, the game transitions to :pie_decision. Win conditions are
  evaluated after every placement.
  """
  @spec place(t(), term()) :: {:ok, t()} | {:error, atom()}
  def place(%__MODULE__{phase: phase} = game, cell) when phase in [:opening, :playing] do
    cond do
      not Board.valid?(cell) ->
        {:error, :invalid_cell}

      Map.get(game.board, cell) != nil ->
        {:error, :cell_occupied}

      true ->
        side = player_side(game, game.current_player)
        game = %{game | board: Map.put(game.board, cell, side), last_move: cell}
        {:ok, resolve_move(game, side)}
    end
  end

  def place(%__MODULE__{}, _), do: {:error, :game_not_playing}

  @doc """
  Records the second player's pie rule decision after the first move.
  choice must be :swap or :keep.

  :swap exchanges the player-to-side mapping; the board is unchanged.
  :keep continues with the existing assignment.

  Returns {:ok, updated_game} | {:error, reason}.
  """
  @spec pie_decision(t(), term()) :: {:ok, t()} | {:error, atom()}
  def pie_decision(%__MODULE__{phase: :pie_decision} = game, choice)
      when choice in [:swap, :keep] do
    game = if choice == :swap, do: swap_sides(game), else: game
    next = if choice == :swap, do: next_player(game), else: game.current_player
    {:ok, %{game | phase: :playing, current_player: next}}
  end

  def pie_decision(%__MODULE__{phase: phase}, _choice) when phase != :pie_decision,
    do: {:error, :invalid_phase}

  def pie_decision(%__MODULE__{}, _choice), do: {:error, :invalid_choice}

  @doc """
  Resigns the given player. The opposing side wins with reason :resignation.
  Valid in :opening, :pie_decision, and :playing phases.
  Returns {:ok, updated_game} | {:error, reason}.
  """
  @spec resign(t(), player()) :: {:ok, t()} | {:error, atom()}
  def resign(%__MODULE__{phase: phase} = game, player)
      when phase in [:opening, :pie_decision, :playing] do
    finish(game, player, :resignation)
  end

  def resign(%__MODULE__{}, _), do: {:error, :game_not_playing}

  @doc "Ends an active game when a player's move clock expires."
  @spec timeout(t()) :: {:ok, t()} | {:error, :game_not_playing}
  def timeout(%__MODULE__{phase: phase} = game)
      when phase in [:opening, :pie_decision, :playing] do
    finish(game, game.current_player, :timeout)
  end

  def timeout(%__MODULE__{}), do: {:error, :game_not_playing}

  defp finish(game, player, reason) do
    case player_side(game, player) do
      nil -> {:error, :unknown_player}
      side -> {:ok, %{game | phase: :game_over, winner: other_side(side), win_reason: reason}}
    end
  end

  defp resolve_move(game, side) do
    case Rules.check_win(game.board, side) do
      :none ->
        phase = if game.phase == :opening, do: :pie_decision, else: :playing
        %{game | current_player: next_player(game), phase: phase}

      reason ->
        %{game | phase: :game_over, winner: side, win_reason: reason}
    end
  end

  defp swap_sides(%__MODULE__{sides: sides, players: [p1, p2]} = game) do
    %{game | sides: %{p1 => sides[p2], p2 => sides[p1]}}
  end

  defp next_player(%__MODULE__{players: [p1, p2], current_player: current}) do
    if current == p1, do: p2, else: p1
  end

  defp other_side(:blue), do: :red
  defp other_side(:red), do: :blue
end
