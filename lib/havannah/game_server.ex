defmodule Havannah.GameServer do
  @moduledoc """
  Authoritative game process for a single Havannah match.

  Holds all game state. All moves go through here; the LiveView layer only
  subscribes and renders. Broadcasts {:game_updated, state} on every change.

  Players are identified by session IDs (strings). Internally the pure
  Havannah.Game struct uses :player_1 / :player_2 as player identities.

  State shape:
    id          - unique game ID
    mode        - :human_vs_human | :human_vs_ai
    game        - %Havannah.Game{}
    slots       - %{player_1: :open | session_id, player_2: :open | :ai | session_id}
    assignments - %{session_id => :player_1 | :player_2 | :spectator}
    status      - :waiting | :playing | :ai_thinking
  """

  use GenServer

  alias Havannah.{AI, Game}

  @ai_delay_ms 200..500

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link({game_id, mode}) do
    GenServer.start_link(__MODULE__, {game_id, mode}, name: via(game_id))
  end

  @doc "Returns {:ok, state} or {:error, :not_found}."
  def get_state(game_id) do
    with_server(game_id, fn pid -> GenServer.call(pid, :get_state) end)
  end

  @doc """
  Assigns a role to a session. First human gets :player_1, second :player_2,
  rest are :spectators. Re-joining an existing session returns the stored role.
  Returns {:ok, role} or {:error, :not_found}.
  """
  def join(game_id, session_id) do
    with_server(game_id, fn pid -> GenServer.call(pid, {:join, session_id}) end)
  end

  @doc """
  Attempts to place a stone at {q, r} on behalf of session_id.
  Returns :ok | {:error, reason}.
  """
  def place(game_id, session_id, cell) do
    with_server(game_id, fn pid -> GenServer.call(pid, {:place, session_id, cell}) end)
  end

  @doc """
  Records the second player's pie rule decision (:swap or :keep).
  Returns :ok | {:error, reason}.
  """
  def pie_decision(game_id, session_id, choice) do
    with_server(game_id, fn pid -> GenServer.call(pid, {:pie_decision, session_id, choice}) end)
  end

  @doc "Registration tuple for the Registry."
  def via(game_id) do
    {:via, Registry, {Havannah.GameRegistry, game_id}}
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init({game_id, mode}) do
    game = Game.new(:player_1, :player_2)

    slots =
      case mode do
        :human_vs_ai -> %{player_1: :open, player_2: :ai}
        :human_vs_human -> %{player_1: :open, player_2: :open}
      end

    state = %{
      id: game_id,
      mode: mode,
      game: game,
      slots: slots,
      assignments: %{},
      status: :waiting
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, public_state(state)}, state}
  end

  @impl true
  def handle_call({:join, session_id}, _from, state) do
    cond do
      Map.has_key?(state.assignments, session_id) ->
        # Already joined; return existing role without mutating state
        {:reply, {:ok, state.assignments[session_id]}, state}

      state.slots.player_1 == :open ->
        state = fill_slot(state, :player_1, session_id)
        {:reply, {:ok, :player_1}, state}

      state.slots.player_2 == :open ->
        state = fill_slot(state, :player_2, session_id)
        {:reply, {:ok, :player_2}, state}

      true ->
        state = put_in(state.assignments[session_id], :spectator)
        {:reply, {:ok, :spectator}, state}
    end
  end

  @impl true
  def handle_call({:place, session_id, cell}, _from, state) do
    role = Map.get(state.assignments, session_id)

    cond do
      is_nil(role) ->
        {:reply, {:error, :not_in_game}, state}

      role == :spectator ->
        {:reply, {:error, :spectator_cannot_move}, state}

      state.status == :ai_thinking ->
        {:reply, {:error, :ai_thinking}, state}

      state.game.current_player != role ->
        {:reply, {:error, :not_your_turn}, state}

      true ->
        case Game.place(state.game, cell) do
          {:ok, new_game} ->
            state = %{state | game: new_game}

            state =
              if new_game.phase == :game_over, do: %{state | status: :game_over}, else: state

            state = maybe_schedule_ai(state)
            broadcast(state)
            {:reply, :ok, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:pie_decision, session_id, choice}, _from, state) do
    role = Map.get(state.assignments, session_id)

    cond do
      is_nil(role) ->
        {:reply, {:error, :not_in_game}, state}

      role == :spectator ->
        {:reply, {:error, :spectator_cannot_decide}, state}

      state.game.phase != :pie_decision ->
        {:reply, {:error, :invalid_phase}, state}

      state.game.current_player != role ->
        {:reply, {:error, :not_your_turn}, state}

      true ->
        case Game.pie_decision(state.game, choice) do
          {:ok, new_game} ->
            state = %{state | game: new_game}
            state = maybe_schedule_ai(state)
            broadcast(state)
            {:reply, :ok, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_info(:ai_move, state) do
    cond do
      state.status == :ai_thinking and state.game.phase == :pie_decision and
          state.game.current_player == :player_2 ->
        choice = Enum.random([:swap, :keep])
        {:ok, new_game} = Game.pie_decision(state.game, choice)
        state = %{state | game: new_game}
        state = maybe_schedule_ai(state)
        broadcast(state)
        {:noreply, state}

      state.status == :ai_thinking and state.game.current_player == :player_2 and
          state.game.phase == :playing ->
        case AI.random_move(state.game) do
          {:ok, cell} ->
            {:ok, new_game} = Game.place(state.game, cell)
            new_status = if new_game.phase == :game_over, do: :game_over, else: :playing
            state = %{state | game: new_game, status: new_status}
            broadcast(state)
            {:noreply, state}

          {:error, :no_moves} ->
            {:noreply, %{state | status: :playing}}
        end

      true ->
        {:noreply, state}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp fill_slot(state, role, session_id) do
    state
    |> put_in([:slots, role], session_id)
    |> put_in([:assignments, session_id], role)
    |> update_status()
    |> tap(&broadcast/1)
  end

  defp update_status(state) do
    ready =
      case state.mode do
        :human_vs_ai -> state.slots.player_1 != :open
        :human_vs_human -> state.slots.player_1 != :open and state.slots.player_2 != :open
      end

    if ready, do: %{state | status: :playing}, else: state
  end

  defp maybe_schedule_ai(%{mode: :human_vs_ai, game: game} = state)
       when game.current_player == :player_2 and game.phase in [:pie_decision, :playing] do
    Process.send_after(self(), :ai_move, Enum.random(@ai_delay_ms))
    %{state | status: :ai_thinking}
  end

  defp maybe_schedule_ai(state), do: state

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(
      Havannah.PubSub,
      "game:#{state.id}",
      {:game_updated, public_state(state)}
    )
  end

  defp public_state(state) do
    %{
      id: state.id,
      mode: state.mode,
      game: state.game,
      slots: state.slots,
      status: state.status
    }
  end

  defp with_server(game_id, fun) do
    case Registry.lookup(Havannah.GameRegistry, game_id) do
      [{pid, _}] -> fun.(pid)
      [] -> {:error, :not_found}
    end
  end
end
