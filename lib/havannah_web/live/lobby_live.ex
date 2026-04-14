defmodule HavannahWeb.LobbyLive do
  use HavannahWeb, :live_view

  alias Havannah.GameSupervisor

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :mode, :human_vs_human)}
  end

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :mode, String.to_existing_atom(mode))}
  end

  @impl true
  def handle_event("create_game", _params, socket) do
    {:ok, game_id} = GameSupervisor.start_game(socket.assigns.mode)
    {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex flex-col items-center gap-8 py-12">
        <div class="text-center">
          <h1 class="text-3xl font-bold text-base-content">Havannah</h1>
          <p class="mt-2 text-base-content/60">A connection strategy board game</p>
        </div>

        <div class="card bg-base-200 shadow-md w-full max-w-sm">
          <div class="card-body gap-6">
            <h2 class="card-title text-base-content">New Game</h2>

            <div class="flex flex-col gap-3">
              <p class="text-sm font-medium text-base-content/70">Game mode</p>

              <label class={[
                "flex items-center gap-3 p-3 rounded-lg border-2 cursor-pointer transition-colors",
                @mode == :human_vs_human && "border-primary bg-primary/10",
                @mode != :human_vs_human && "border-base-300 hover:border-base-content/30"
              ]}>
                <input
                  type="radio"
                  name="mode"
                  value="human_vs_human"
                  checked={@mode == :human_vs_human}
                  phx-click="set_mode"
                  phx-value-mode="human_vs_human"
                  class="radio radio-primary radio-sm"
                />
                <div>
                  <div class="font-medium text-base-content text-sm">Human vs Human</div>
                  <div class="text-xs text-base-content/50">Share the link with a friend</div>
                </div>
              </label>

              <label class={[
                "flex items-center gap-3 p-3 rounded-lg border-2 cursor-pointer transition-colors",
                @mode == :human_vs_ai && "border-primary bg-primary/10",
                @mode != :human_vs_ai && "border-base-300 hover:border-base-content/30"
              ]}>
                <input
                  type="radio"
                  name="mode"
                  value="human_vs_ai"
                  checked={@mode == :human_vs_ai}
                  phx-click="set_mode"
                  phx-value-mode="human_vs_ai"
                  class="radio radio-primary radio-sm"
                />
                <div>
                  <div class="font-medium text-base-content text-sm">Human vs AI</div>
                  <div class="text-xs text-base-content/50">Play against a random AI</div>
                </div>
              </label>
            </div>

            <button phx-click="create_game" class="btn btn-primary w-full">
              Create Game
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
