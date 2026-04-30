defmodule HavannahWeb.GameLive do
  use HavannahWeb, :live_view

  alias Havannah.{Game, GameServer, GameSupervisor}

  # SVG layout constants for a pointy-top hex grid.
  # viewBox is "0 0 700 620"; board is centered at (@svg_cx, @svg_cy).
  @hex_size 20.0
  @svg_cx 350.0
  @svg_cy 310.0

  # ---------------------------------------------------------------------------
  # Lifecycle
  # ---------------------------------------------------------------------------

  @impl true
  def mount(%{"id" => game_id}, session, socket) do
    session_id = Map.get(session, "session_id", socket.id)

    case GameServer.get_state(game_id) do
      {:error, :not_found} ->
        {:ok, push_navigate(socket, to: ~p"/")}

      {:ok, game_state} ->
        socket =
          socket
          |> assign(:game_id, game_id)
          |> assign(:session_id, session_id)
          |> assign(:game_state, game_state)
          |> assign(:role, nil)
          |> assign(:remaining_seconds, nil)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(Havannah.PubSub, "game:#{game_id}")
          {:ok, role} = GameServer.join(game_id, session_id)
          {:ok, updated_state} = GameServer.get_state(game_id)

          socket =
            socket
            |> assign(:role, role)
            |> assign(:game_state, updated_state)
            |> assign(:board_cells, build_board_cells(updated_state.game))
            |> assign(:remaining_seconds, remaining_seconds(updated_state.move_deadline))
            |> schedule_tick()

          {:ok, socket}
        else
          {:ok, assign(socket, :board_cells, build_board_cells(game_state.game))}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("place", %{"q" => q_str, "r" => r_str}, socket) do
    q = String.to_integer(q_str)
    r = String.to_integer(r_str)
    GameServer.place(socket.assigns.game_id, socket.assigns.session_id, {q, r})
    {:noreply, socket}
  end

  def handle_event("pie_decision", %{"choice" => choice}, socket) do
    choice_atom = String.to_existing_atom(choice)
    GameServer.pie_decision(socket.assigns.game_id, socket.assigns.session_id, choice_atom)
    {:noreply, socket}
  end

  def handle_event("resign", _params, socket) do
    GameServer.resign(socket.assigns.game_id, socket.assigns.session_id)
    {:noreply, socket}
  end

  def handle_event("rematch", _params, socket) do
    mode = socket.assigns.game_state.mode
    {:ok, game_id} = GameSupervisor.start_game(mode)
    {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}")}
  end

  # ---------------------------------------------------------------------------
  # PubSub + timer tick
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:game_updated, game_state}, socket) do
    socket =
      socket
      |> assign(:game_state, game_state)
      |> assign(:board_cells, build_board_cells(game_state.game))
      |> assign(:remaining_seconds, remaining_seconds(game_state.move_deadline))
      |> schedule_tick()

    {:noreply, socket}
  end

  def handle_info(:tick, socket) do
    socket =
      socket
      |> assign(:remaining_seconds, remaining_seconds(socket.assigns.game_state.move_deadline))
      |> schedule_tick()

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Rendering
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="havannah-game" class="flex flex-col items-center gap-4">
        <%!-- Top bar: status dot + text + timer + rematch/resign --%>
        <div class="w-full flex items-center justify-between gap-3">
          <div class="flex items-center gap-2 min-w-0">
            <div class={[
              "w-4 h-4 shrink-0 rounded-full shadow-sm",
              current_side(@game_state) == :blue && "bg-blue-500",
              current_side(@game_state) == :red && "bg-red-500",
              is_nil(current_side(@game_state)) && "bg-base-300"
            ]}>
            </div>
            <span class="font-semibold text-base-content text-sm truncate">
              {status_text(assigns)}
            </span>
          </div>

          <div class="flex items-center gap-2 shrink-0">
            <%!-- Per-move countdown timer --%>
            <%= if @remaining_seconds && @game_state.game.phase in [:opening, :pie_decision, :playing] do %>
              <div class={[
                "font-mono text-sm font-semibold tabular-nums px-2 py-0.5 rounded-lg",
                @remaining_seconds > 60 && "text-base-content/60",
                @remaining_seconds <= 60 && @remaining_seconds > 20 && "text-warning",
                @remaining_seconds <= 20 && "text-error animate-pulse"
              ]}>
                {format_time(@remaining_seconds)}
              </div>
            <% end %>

            <%!-- Resign button (active games, human players only) --%>
            <%= if can_resign?(assigns) do %>
              <button
                phx-click={JS.show(to: "#resign-confirm")}
                class="btn btn-sm btn-ghost text-base-content/50 hover:text-error"
              >
                Resign
              </button>
            <% end %>

            <%!-- Rematch button (game over only) --%>
            <%= if @game_state.game.phase == :game_over do %>
              <button phx-click="rematch" class="btn btn-sm btn-primary">
                Rematch
              </button>
            <% end %>
          </div>
        </div>

        <%!-- Info row: mode / role / pie outcome / share --%>
        <div class="w-full flex flex-wrap items-center gap-3 text-xs text-base-content/50">
          <span class="badge badge-ghost badge-sm">{mode_label(@game_state.mode)}</span>

          <%= if @role do %>
            <span class={[
              "badge badge-sm",
              @role == :player_1 && "badge-info",
              @role == :player_2 && "badge-error",
              @role == :spectator && "badge-ghost"
            ]}>
              {role_label(@role, @game_state)}
            </span>
          <% end %>

          <%= if pie_rule_outcome(@game_state.game) do %>
            <span class={[
              "badge badge-sm badge-outline",
              pie_rule_outcome(@game_state.game) == :swapped && "badge-warning",
              pie_rule_outcome(@game_state.game) == :kept && "badge-ghost"
            ]}>
              Pie: {if pie_rule_outcome(@game_state.game) == :swapped, do: "Swapped", else: "Kept"}
            </span>
          <% end %>

          <%= if @game_state.mode == :human_vs_human do %>
            <span class="ml-auto flex items-center gap-1">
              Share:
              <span
                class="font-mono text-base-content/70 underline cursor-pointer"
                title={game_url(@game_state.id)}
                phx-click={JS.dispatch("phx:copy", detail: %{text: game_url(@game_state.id)})}
              >
                /game/{@game_state.id}
              </span>
            </span>
          <% end %>
        </div>

        <%!-- Legend + last move --%>
        <div class="w-full flex gap-4 text-xs text-base-content/50">
          <span class="flex items-center gap-1">
            <span class={[
              "inline-block w-2.5 h-2.5 rounded-full",
              Game.player_side(@game_state.game, :player_1) == :blue && "bg-blue-500",
              Game.player_side(@game_state.game, :player_1) == :red && "bg-red-500"
            ]}>
            </span>
            {player_side_label(@game_state, :player_1)}
          </span>
          <span class="flex items-center gap-1">
            <span class={[
              "inline-block w-2.5 h-2.5 rounded-full",
              Game.player_side(@game_state.game, :player_2) == :blue && "bg-blue-500",
              Game.player_side(@game_state.game, :player_2) == :red && "bg-red-500"
            ]}>
            </span>
            {player_side_label(@game_state, :player_2)}
          </span>
          <%= if @game_state.game.last_move do %>
            <span class="ml-auto flex items-center gap-1">
              <span class="inline-block w-2.5 h-2.5 rounded-sm border-2 border-amber-400"></span>
              Last ({elem(@game_state.game.last_move, 0)}, {elem(@game_state.game.last_move, 1)})
            </span>
          <% end %>
        </div>

        <%!-- Pie rule decision prompt --%>
        <%= if @game_state.game.phase == :pie_decision and @role == :player_2 do %>
          <div
            id="pie-decision"
            class="w-full rounded-xl border border-amber-400/40 bg-amber-50/10 p-4 text-center"
          >
            <p class="mb-1 text-sm font-semibold text-base-content">
              Pie Rule — Do you want to swap sides?
            </p>
            <p class="mb-3 text-xs text-base-content/50">
              Blue made the first move. Swap to take their side, or keep yours.
            </p>
            <div class="flex justify-center gap-3">
              <button
                id="pie-swap"
                phx-click="pie_decision"
                phx-value-choice="swap"
                class="btn btn-sm btn-warning"
              >
                Swap
              </button>
              <button
                id="pie-keep"
                phx-click="pie_decision"
                phx-value-choice="keep"
                class="btn btn-sm btn-ghost"
              >
                Keep
              </button>
            </div>
          </div>
        <% end %>

        <%!-- Board --%>
        <div class="w-full overflow-x-auto">
          <svg
            id="havannah-board"
            viewBox="0 0 700 620"
            width="100%"
            xmlns="http://www.w3.org/2000/svg"
            class="touch-none select-none"
            style="max-height: 80vh; min-width: 280px;"
          >
            <%= for cell <- @board_cells do %>
              <polygon
                id={"hex-#{cell.q}-#{cell.r}"}
                points={cell.points}
                class={[
                  "hex-cell",
                  is_nil(cell.side) && "hex-empty",
                  cell.side == :blue && "hex-blue",
                  cell.side == :red && "hex-red",
                  cell.last_move && "hex-last-move"
                ]}
                phx-click={can_move?(assigns, cell) && "place"}
                phx-value-q={cell.q}
                phx-value-r={cell.r}
              />
            <% end %>
          </svg>
        </div>
      </div>

      <%!-- Resign confirmation modal --%>
      <div
        id="resign-confirm"
        class="hidden fixed inset-0 z-50 flex items-center justify-center p-4"
        role="dialog"
        aria-modal="true"
      >
        <div
          class="absolute inset-0 bg-black/50"
          phx-click={JS.hide(to: "#resign-confirm")}
        >
        </div>
        <div class="relative bg-base-100 rounded-2xl shadow-2xl p-6 max-w-xs w-full">
          <h3 class="text-base font-bold text-base-content mb-2">Resign?</h3>
          <p class="text-sm text-base-content/70 mb-5">
            Your opponent will win. This cannot be undone.
          </p>
          <div class="flex gap-3">
            <button
              phx-click={JS.hide(to: "#resign-confirm") |> JS.push("resign")}
              class="btn btn-error btn-sm flex-1"
            >
              Yes, resign
            </button>
            <button
              phx-click={JS.hide(to: "#resign-confirm")}
              class="btn btn-ghost btn-sm flex-1"
            >
              Cancel
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_board_cells(game) do
    Enum.map(game.board, fn {{q, r}, side} ->
      %{
        q: q,
        r: r,
        side: side,
        points: hex_polygon_points(q, r),
        last_move: {q, r} == game.last_move
      }
    end)
  end

  defp hex_polygon_points(q, r) do
    cx = :math.sqrt(3) * q * @hex_size + :math.sqrt(3) / 2 * r * @hex_size + @svg_cx
    cy = 1.5 * r * @hex_size + @svg_cy

    Enum.map(0..5, fn i ->
      angle_rad = :math.pi() / 180.0 * (30.0 + 60.0 * i)
      vx = Float.round(cx + @hex_size * :math.cos(angle_rad), 2)
      vy = Float.round(cy + @hex_size * :math.sin(angle_rad), 2)
      "#{vx},#{vy}"
    end)
    |> Enum.join(" ")
  end

  defp can_move?(%{role: role, game_state: gs} = _assigns, cell) do
    is_nil(cell.side) and
      role in [:player_1, :player_2] and
      gs.status == :playing and
      gs.game.phase in [:opening, :playing] and
      gs.game.current_player == role
  end

  defp can_resign?(%{role: role, game_state: gs}) do
    role in [:player_1, :player_2] and
      gs.game.phase in [:opening, :pie_decision, :playing]
  end

  defp remaining_seconds(nil), do: nil

  defp remaining_seconds(deadline) do
    ms = deadline - :os.system_time(:millisecond)
    max(0, div(ms, 1000))
  end

  defp schedule_tick(socket) do
    if socket.assigns.game_state.move_deadline &&
         socket.assigns.game_state.game.phase in [:opening, :pie_decision, :playing] do
      Process.send_after(self(), :tick, 1000)
    end

    socket
  end

  defp format_time(seconds) do
    m = div(seconds, 60)
    s = rem(seconds, 60)
    "#{m}:#{String.pad_leading("#{s}", 2, "0")}"
  end

  defp pie_rule_outcome(%{phase: phase}) when phase in [:opening, :pie_decision], do: nil

  defp pie_rule_outcome(%{sides: sides}),
    do: if(sides[:player_1] == :blue, do: :kept, else: :swapped)

  defp current_side(%{game: game}) do
    Game.player_side(game, game.current_player)
  end

  defp status_text(%{game_state: %{status: :waiting}} = _assigns) do
    "Waiting for players…"
  end

  defp status_text(%{game_state: %{status: :ai_thinking}} = _assigns) do
    "AI is thinking…"
  end

  defp status_text(%{game_state: %{status: :game_over} = gs} = _assigns) do
    winner_side = gs.game.winner
    winner_player = Enum.find_value(gs.game.sides, fn {p, s} -> if s == winner_side, do: p end)
    win_label = win_reason_label(gs.game.win_reason)
    "#{player_label(winner_player, gs)} wins by #{win_label}"
  end

  defp status_text(%{role: role, game_state: %{game: %{phase: :pie_decision}} = gs} = _assigns) do
    current = gs.game.current_player

    if role == current do
      "Your turn — swap sides or keep?"
    else
      "#{player_label(current, gs)} is deciding on the pie rule…"
    end
  end

  defp status_text(%{role: role, game_state: gs} = _assigns) do
    current = gs.game.current_player
    side = Game.player_side(gs.game, current)
    side_str = side_label(side)

    if role == current do
      "Your turn (#{side_str})"
    else
      "#{player_label(current, gs)}'s turn (#{side_str})"
    end
  end

  defp win_reason_label(:bridge), do: "bridge"
  defp win_reason_label(:fork), do: "fork"
  defp win_reason_label(:ring), do: "ring"
  defp win_reason_label(:resignation), do: "resignation"
  defp win_reason_label(:timeout), do: "timeout"
  defp win_reason_label(nil), do: "winning"

  defp player_label(role, game_state) do
    case {role, game_state.mode} do
      {:player_2, :human_vs_ai} -> "AI"
      {:player_1, _} -> "Player 1"
      {:player_2, _} -> "Player 2"
    end
  end

  defp player_side_label(game_state, role) do
    side = Game.player_side(game_state.game, role)
    name = player_label(role, game_state)
    "#{name} — #{side_label(side)}"
  end

  defp role_label(:player_1, gs) do
    side = Game.player_side(gs.game, :player_1)
    "You are Player 1 (#{side_label(side)})"
  end

  defp role_label(:player_2, gs) do
    side = Game.player_side(gs.game, :player_2)
    "You are Player 2 (#{side_label(side)})"
  end

  defp role_label(:spectator, _gs), do: "Spectator"

  defp mode_label(:human_vs_human), do: "Human vs Human"
  defp mode_label(:human_vs_ai), do: "Human vs AI"

  defp side_label(:blue), do: "Blue"
  defp side_label(:red), do: "Red"
  defp side_label(nil), do: ""

  defp game_url(game_id) do
    HavannahWeb.Endpoint.url() <> ~p"/game/#{game_id}"
  end
end
