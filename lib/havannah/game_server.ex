defmodule Havannah.GameServer do
  @moduledoc """
  Authoritative, in-memory process for one match.

  Session identities stay private. Subscribers receive `{:game_updated, state}`
  with board state, slot availability, status, and a wall-clock move deadline.
  Timer references identify turns so cancelled messages cannot end a later turn.
  Games are temporary children: a crash cannot silently recreate an empty match.
  """

  use GenServer, restart: :temporary

  alias Havannah.{AI, Game}

  @move_timeout_ms 5 * 60 * 1000

  def start_link({game_id, mode}) do
    GenServer.start_link(__MODULE__, {game_id, mode}, name: via(game_id))
  end

  @doc "Returns the public snapshot, or `{:error, :not_found}`."
  def get_state(game_id), do: call(game_id, :get_state)

  @doc "Claims an available player slot; additional sessions are spectators."
  def join(game_id, session_id), do: call(game_id, {:join, session_id})

  def place(game_id, session_id, cell), do: call(game_id, {:place, session_id, cell})

  def pie_decision(game_id, session_id, choice),
    do: call(game_id, {:pie_decision, session_id, choice})

  def resign(game_id, session_id), do: call(game_id, {:resign, session_id})

  def via(game_id), do: {:via, Registry, {Havannah.GameRegistry, game_id}}

  defp call(game_id, message) do
    GenServer.call(via(game_id), message)
  catch
    :exit, {:noproc, _} -> {:error, :not_found}
    :exit, {:normal, _} -> {:error, :not_found}
    :exit, {:shutdown, _} -> {:error, :not_found}
  end

  @impl true
  def init({game_id, mode}), do: init({game_id, mode, []})

  def init({game_id, mode, opts}) do
    slots = %{
      player_1: :open,
      player_2: if(mode == :human_vs_ai, do: :ai, else: :open)
    }

    {:ok,
     %{
       id: game_id,
       mode: mode,
       game: Game.new(:player_1, :player_2),
       slots: slots,
       assignments: %{},
       status: :waiting,
       timer_ref: nil,
       ai_ref: nil,
       move_deadline: nil,
       move_timeout_ms: Keyword.get(opts, :move_timeout_ms, @move_timeout_ms),
       ai_delay_ms: Keyword.get(opts, :ai_delay_ms, 200..500)
     }}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, public_state(state)}, state}
  end

  def handle_call({:join, session_id}, _from, state) when is_binary(session_id) do
    case Map.fetch(state.assignments, session_id) do
      {:ok, role} ->
        {:reply, {:ok, role}, state}

      :error ->
        join_slot(state, session_id)
    end
  end

  def handle_call({:join, _}, _from, state),
    do: {:reply, {:error, :invalid_session}, state}

  def handle_call({action, session_id, value}, _from, state)
      when action in [:place, :pie_decision] do
    with {:ok, role} <- authorize(state, session_id, action),
         :ok <- validate_turn(state, role, action),
         {:ok, game} <- apply_action(state.game, action, value) do
      state = transition(state, game)
      {:reply, :ok, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:resign, session_id}, _from, state) do
    with {:ok, role} <- authorize(state, session_id, :resign),
         {:ok, game} <- Game.resign(state.game, role) do
      {:reply, :ok, transition(state, game)}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info({:timeout, ref, :ai_move}, %{ai_ref: ref, status: :ai_thinking} = state) do
    result =
      case state.game.phase do
        :pie_decision ->
          Game.pie_decision(state.game, Enum.random([:swap, :keep]))

        :playing ->
          with {:ok, cell} <- AI.random_move(state.game), do: Game.place(state.game, cell)
      end

    case result do
      {:ok, game} -> {:noreply, transition(state, game)}
      {:error, :no_moves} -> {:noreply, %{state | ai_ref: nil, status: :playing}}
    end
  end

  def handle_info({:timeout, ref, :move_timeout}, %{timer_ref: ref} = state)
      when is_reference(ref) do
    {:ok, game} = Game.timeout(state.game)
    {:noreply, transition(state, game)}
  end

  # Messages already queued before cancellation belong to an obsolete turn.
  def handle_info({:timeout, _ref, kind}, state) when kind in [:move_timeout, :ai_move],
    do: {:noreply, state}

  defp join_slot(state, session_id) do
    role = Enum.find([:player_1, :player_2], &(Map.fetch!(state.slots, &1) == :open))

    if role do
      state =
        state
        |> put_in([:slots, role], session_id)
        |> put_in([:assignments, session_id], role)

      state =
        if ready?(state) do
          transition(state, state.game)
        else
          broadcast(state)
          state
        end

      {:reply, {:ok, role}, state}
    else
      state = put_in(state.assignments[session_id], :spectator)
      {:reply, {:ok, :spectator}, state}
    end
  end

  defp ready?(state), do: Enum.all?(state.slots, fn {_role, occupant} -> occupant != :open end)

  defp authorize(state, session_id, action) do
    case Map.get(state.assignments, session_id) do
      nil -> {:error, :not_in_game}
      :spectator -> {:error, spectator_error(action)}
      role -> {:ok, role}
    end
  end

  defp spectator_error(:place), do: :spectator_cannot_move
  defp spectator_error(:pie_decision), do: :spectator_cannot_decide
  defp spectator_error(:resign), do: :spectator_cannot_resign

  defp validate_turn(state, role, action) do
    cond do
      state.status == :waiting -> {:error, :waiting_for_players}
      state.status == :ai_thinking -> {:error, :ai_thinking}
      action == :pie_decision and state.game.phase != :pie_decision -> {:error, :invalid_phase}
      state.game.current_player != role -> {:error, :not_your_turn}
      true -> :ok
    end
  end

  defp apply_action(game, :place, cell), do: Game.place(game, cell)
  defp apply_action(game, :pie_decision, choice), do: Game.pie_decision(game, choice)

  defp transition(state, game) do
    cancel_timer(state.timer_ref)
    cancel_timer(state.ai_ref)
    state = %{state | game: game, timer_ref: nil, ai_ref: nil, move_deadline: nil}

    state =
      cond do
        game.phase == :game_over ->
          %{state | status: :game_over}

        state.mode == :human_vs_ai and game.current_player == :player_2 ->
          delay = state.ai_delay_ms
          delay = if is_integer(delay), do: delay, else: Enum.random(delay)
          ref = :erlang.start_timer(delay, self(), :ai_move)
          %{state | status: :ai_thinking, ai_ref: ref}

        true ->
          ref = :erlang.start_timer(state.move_timeout_ms, self(), :move_timeout)
          deadline = System.system_time(:millisecond) + state.move_timeout_ms
          %{state | status: :playing, timer_ref: ref, move_deadline: deadline}
      end

    broadcast(state)
    state
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(ref), do: Process.cancel_timer(ref)

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(
      Havannah.PubSub,
      "game:#{state.id}",
      {:game_updated, public_state(state)}
    )
  end

  defp public_state(state) do
    slots =
      Map.new(state.slots, fn {role, slot} ->
        {role, if(slot in [:open, :ai], do: slot, else: :occupied)}
      end)

    state
    |> Map.take([:id, :mode, :game, :status, :move_deadline])
    |> Map.put(:slots, slots)
  end
end
