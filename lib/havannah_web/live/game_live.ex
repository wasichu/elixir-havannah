defmodule HavannahWeb.GameLive do
  use HavannahWeb, :live_view

  alias Havannah.Game

  # SVG layout constants for a pointy-top hex grid.
  # viewBox is "0 0 700 620"; board is centered at (@svg_cx, @svg_cy).
  @hex_size 20.0
  @svg_cx 350.0
  @svg_cy 310.0

  @impl true
  def mount(_params, _session, socket) do
    game = Game.new(:player_1, :player_2)

    {:ok,
     socket
     |> assign(:game, game)
     |> assign(:board_cells, build_board_cells(game))}
  end

  @impl true
  def handle_event("place", %{"q" => q_str, "r" => r_str}, socket) do
    q = String.to_integer(q_str)
    r = String.to_integer(r_str)

    case Game.place(socket.assigns.game, {q, r}) do
      {:ok, new_game} ->
        {:noreply,
         socket
         |> assign(:game, new_game)
         |> assign(:board_cells, build_board_cells(new_game))}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("new_game", _params, socket) do
    game = Game.new(:player_1, :player_2)

    {:noreply,
     socket
     |> assign(:game, game)
     |> assign(:board_cells, build_board_cells(game))}
  end

  # Pre-compute per-cell rendering data once per game state change.
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

  # Pointy-top hexagon: center pixel from axial (q, r), then 6 vertices at
  # angles 30°, 90°, 150°, 210°, 270°, 330° from the center.
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

  defp player_label(:player_1), do: "Player 1"
  defp player_label(:player_2), do: "Player 2"

  defp side_label(:blue), do: "Blue"
  defp side_label(:red), do: "Red"
  defp side_label(nil), do: ""

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="havannah-game" class="flex flex-col items-center gap-4">
        <%!-- Status bar --%>
        <div class="w-full flex items-center justify-between">
          <div class="flex items-center gap-2">
            <div class={[
              "w-4 h-4 rounded-full shadow-sm",
              Game.player_side(@game, @game.current_player) == :blue && "bg-blue-500",
              Game.player_side(@game, @game.current_player) == :red && "bg-red-500"
            ]}>
            </div>
            <span class="font-semibold text-base-content text-sm">
              {player_label(@game.current_player)}'s turn
              <span class={[
                "ml-1 font-normal",
                Game.player_side(@game, @game.current_player) == :blue && "text-blue-500",
                Game.player_side(@game, @game.current_player) == :red && "text-red-500"
              ]}>
                ({side_label(Game.player_side(@game, @game.current_player))})
              </span>
            </span>
          </div>

          <button
            id="new-game-btn"
            phx-click="new_game"
            class="btn btn-sm btn-ghost text-base-content/60 hover:text-base-content"
          >
            New Game
          </button>
        </div>

        <%!-- Side legend --%>
        <div class="w-full flex gap-4 text-xs text-base-content/50">
          <span class="flex items-center gap-1">
            <span class="inline-block w-2.5 h-2.5 rounded-full bg-blue-500"></span> Player 1 — Blue
          </span>
          <span class="flex items-center gap-1">
            <span class="inline-block w-2.5 h-2.5 rounded-full bg-red-500"></span> Player 2 — Red
          </span>
          <%= if @game.last_move do %>
            <span class="ml-auto flex items-center gap-1">
              <span class="inline-block w-2.5 h-2.5 rounded-sm border-2 border-amber-400"></span>
              Last move ({elem(@game.last_move, 0)}, {elem(@game.last_move, 1)})
            </span>
          <% end %>
        </div>

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
                phx-click={is_nil(cell.side) && "place"}
                phx-value-q={cell.q}
                phx-value-r={cell.r}
              />
            <% end %>
          </svg>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
