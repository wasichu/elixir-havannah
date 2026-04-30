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
          phase: :opening | :pie_decision | :playing | :game_over,
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
      phase: :opening,
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

  Valid in :opening and :playing phases. After a successful placement in
  :opening, the game transitions to :pie_decision. Win conditions are
  evaluated after every placement.
  """
  def place(%__MODULE__{phase: phase} = game, {q, r}) when phase in [:opening, :playing] do
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
            next_phase = if phase == :opening, do: :pie_decision, else: :playing

            {:ok,
             %{
               game
               | board: new_board,
                 current_player: next,
                 last_move: {q, r},
                 phase: next_phase
             }}

          _win ->
            {:ok, %{game | board: new_board, phase: :game_over, winner: side, last_move: {q, r}}}
        end
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
  def pie_decision(%__MODULE__{phase: :pie_decision} = game, choice)
      when choice in [:swap, :keep] do
    game = if choice == :swap, do: swap_sides(game), else: game
    next = if choice == :swap, do: next_player(game), else: game.current_player
    {:ok, %{game | phase: :playing, current_player: next}}
  end

  def pie_decision(%__MODULE__{phase: phase}, _choice) when phase != :pie_decision,
    do: {:error, :invalid_phase}

  def pie_decision(%__MODULE__{}, _choice), do: {:error, :invalid_choice}

  defp swap_sides(%__MODULE__{sides: sides, players: [p1, p2]} = game) do
    %{game | sides: %{p1 => sides[p2], p2 => sides[p1]}}
  end

  defp next_player(%__MODULE__{players: [p1, p2], current_player: current}) do
    if current == p1, do: p2, else: p1
  end
end
