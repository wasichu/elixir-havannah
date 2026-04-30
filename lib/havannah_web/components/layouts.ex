defmodule HavannahWeb.Layouts do
  @moduledoc false
  use HavannahWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%!-- Rules modal (controlled by JS show/hide, no LiveView round-trip) --%>
    <div
      id="rules-modal"
      class="hidden fixed inset-0 z-50 flex items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="rules-modal-title"
    >
      <div
        class="absolute inset-0 bg-black/50"
        phx-click={JS.hide(to: "#rules-modal")}
      >
      </div>
      <div class="relative bg-base-100 rounded-2xl shadow-2xl max-w-lg w-full max-h-[80vh] overflow-y-auto">
        <div class="flex items-center justify-between p-5 border-b border-base-300">
          <h2 id="rules-modal-title" class="text-lg font-bold text-base-content">
            How to Play Havannah
          </h2>
          <button
            phx-click={JS.hide(to: "#rules-modal")}
            class="btn btn-ghost btn-sm btn-circle"
            aria-label="Close"
          >
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>
        <div class="p-5 space-y-4 text-sm text-base-content/80">
          <div>
            <h3 class="font-semibold text-base-content mb-1">Basics</h3>
            <p>
              Two players take turns placing stones on empty hexagons. Blue moves first. The board is a hexagonal grid of size&nbsp;10.
            </p>
          </div>
          <div>
            <h3 class="font-semibold text-base-content mb-1">Pie Rule</h3>
            <p>
              After the first move, the second player may <strong>swap sides</strong>
              (taking ownership of the first stone) or <strong>keep</strong>
              their original colour. This balances the first-move advantage.
            </p>
          </div>
          <div>
            <h3 class="font-semibold text-base-content mb-1">How to Win</h3>
            <p class="mb-3">A player wins by forming <em>any one</em> of these three structures:</p>
            <ul class="space-y-4 pl-1">
              <li>
                <p class="font-semibold text-base-content mb-1">Bridge</p>
                <svg
                  viewBox="-6 7 126 34"
                  width="126"
                  height="34"
                  role="img"
                  aria-label="Bridge: five hexagons in a row; the two end hexagons are board corners, shown in amber with board-edge lines diverging from their outer vertices"
                  class="mb-1"
                >
                  <%!-- Board edge lines diverging from left corner outer vertices --%>
                  <line x1="4.6" y1="19" x2="-2.3" y2="15" stroke="#94a3b8" stroke-width="2" stroke-linecap="round" />
                  <line x1="4.6" y1="31" x2="-2.3" y2="35" stroke="#94a3b8" stroke-width="2" stroke-linecap="round" />
                  <%!-- Board edge lines diverging from right corner outer vertices --%>
                  <line x1="108.6" y1="19" x2="115.5" y2="15" stroke="#94a3b8" stroke-width="2" stroke-linecap="round" />
                  <line x1="108.6" y1="31" x2="115.5" y2="35" stroke="#94a3b8" stroke-width="2" stroke-linecap="round" />
                  <%!-- Corner hexes (amber) --%>
                  <polygon
                    points="15,13 25.4,19 25.4,31 15,37 4.6,31 4.6,19"
                    fill="#f59e0b"
                    stroke="#d97706"
                    stroke-width="1"
                  />
                  <polygon
                    points="98.2,13 108.6,19 108.6,31 98.2,37 87.8,31 87.8,19"
                    fill="#f59e0b"
                    stroke="#d97706"
                    stroke-width="1"
                  />
                  <%!-- Bridge chain (blue) --%>
                  <polygon
                    points="35.8,13 46.2,19 46.2,31 35.8,37 25.4,31 25.4,19"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <polygon
                    points="56.6,13 67,19 67,31 56.6,37 46.2,31 46.2,19"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <polygon
                    points="77.4,13 87.8,19 87.8,31 77.4,37 67,31 67,19"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                </svg>
                <p>
                  Connect two different <span class="text-amber-500 font-medium">corners</span>
                  of the board with a single connected group of your stones.
                </p>
              </li>
              <li>
                <p class="font-semibold text-base-content mb-1">Fork</p>
                <svg
                  viewBox="-1 -5 90 102"
                  width="81"
                  height="92"
                  role="img"
                  aria-label="Fork: seven hexagons in a Y-shape, amber lines at three tips mark distinct board edges"
                  class="mb-1"
                >
                  <polygon
                    points="55,33 65.4,39 65.4,51 55,57 44.6,51 44.6,39"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <polygon
                    points="65.4,15 75.8,21 75.8,33 65.4,39 55,33 55,21"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <polygon
                    points="75.8,-3 86.2,3 86.2,15 75.8,21 65.4,15 65.4,3"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <polygon
                    points="65.4,51 75.8,57 75.8,69 65.4,75 55,69 55,57"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <polygon
                    points="75.8,69 86.2,75 86.2,87 75.8,93 65.4,87 65.4,75"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <polygon
                    points="34.2,33 44.6,39 44.6,51 34.2,57 23.8,51 23.8,39"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <polygon
                    points="13.4,33 23.8,39 23.8,51 13.4,57 3,51 3,39"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <line
                    x1="75.8"
                    y1="-3"
                    x2="86.2"
                    y2="3"
                    stroke="#f59e0b"
                    stroke-width="3"
                    stroke-linecap="round"
                  />
                  <line
                    x1="86.2"
                    y1="87"
                    x2="75.8"
                    y2="93"
                    stroke="#f59e0b"
                    stroke-width="3"
                    stroke-linecap="round"
                  />
                  <line
                    x1="3"
                    y1="39"
                    x2="3"
                    y2="51"
                    stroke="#f59e0b"
                    stroke-width="3"
                    stroke-linecap="round"
                  />
                </svg>
                <p>
                  Connect three different <span class="text-amber-500 font-medium">board edges</span>
                  (corners don't count) with a single connected group of your stones.
                </p>
              </li>
              <li>
                <p class="font-semibold text-base-content mb-1">Ring</p>
                <svg
                  viewBox="16 18 70 66"
                  width="70"
                  height="66"
                  role="img"
                  aria-label="Ring: six blue hexagons forming a closed loop around a gray enclosed center hexagon"
                  class="mb-1"
                >
                  <polygon
                    points="70.8,38 81.2,44 81.2,56 70.8,62 60.4,56 60.4,44"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <polygon
                    points="60.4,56 70.8,62 70.8,74 60.4,80 50,74 50,62"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <polygon
                    points="39.6,56 50,62 50,74 39.6,80 29.2,74 29.2,62"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <polygon
                    points="29.2,38 39.6,44 39.6,56 29.2,62 18.8,56 18.8,44"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <polygon
                    points="39.6,20 50,26 50,38 39.6,44 29.2,38 29.2,26"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <polygon
                    points="60.4,20 70.8,26 70.8,38 60.4,44 50,38 50,26"
                    fill="#3b82f6"
                    stroke="#1d4ed8"
                    stroke-width="1"
                  />
                  <polygon
                    points="50,38 60.4,44 60.4,56 50,62 39.6,56 39.6,44"
                    fill="#6b7280"
                    stroke="#4b5563"
                    stroke-width="1"
                  />
                </svg>
                <p>
                  Form a loop of your stones that encloses at least one cell not occupied by you,
                  such that the enclosed area has no path to the edge of the board. The enclosed
                  cells may be empty, opponent stones, or both.
                </p>
              </li>
            </ul>
          </div>
          <div>
            <h3 class="font-semibold text-base-content mb-1">Resign &amp; Timeout</h3>
            <p>
              Either player may resign at any time, conceding the game. Each move has a <strong>5-minute timer</strong>. If the timer runs out, that player loses.
            </p>
          </div>
        </div>
      </div>
    </div>

    <header class="navbar px-4 sm:px-6 lg:px-8 border-b border-base-300/60">
      <div class="flex-1">
        <a href="/" class="flex w-fit items-center gap-2">
          <img src={~p"/images/havannah-logo.svg"} width="28" height="28" alt="Havannah" />
          <span class="text-base font-bold tracking-tight text-base-content">Havannah</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex items-center gap-1">
          <li>
            <button
              phx-click={JS.show(to: "#rules-modal")}
              class="btn btn-ghost btn-sm text-base-content/70 hover:text-base-content"
            >
              How to Play
            </button>
          </li>
          <li>
            <a
              href="https://github.com/wasichu/elixir-havannah"
              target="_blank"
              rel="noopener"
              class="btn btn-ghost btn-sm text-base-content/70 hover:text-base-content"
            >
              GitHub
            </a>
          </li>
          <li>
            <.theme_toggle />
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
