defmodule Havannah.GameSupervisor do
  @moduledoc "DynamicSupervisor that manages one GameServer process per game."

  use DynamicSupervisor

  alias Havannah.GameServer

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new game with the given mode and returns {:ok, game_id}.
  """
  @spec start_game(:human_vs_human | :human_vs_ai) :: {:ok, String.t()} | {:error, term()}
  def start_game(mode) when mode in [:human_vs_human, :human_vs_ai] do
    game_id = generate_id()

    case DynamicSupervisor.start_child(__MODULE__, {GameServer, {game_id, mode}}) do
      {:ok, _pid} -> {:ok, game_id}
      error -> error
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
