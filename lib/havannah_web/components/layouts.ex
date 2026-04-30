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
            <p class="mb-2">A player wins by forming <em>any one</em> of these three structures:</p>
            <ul class="space-y-2 pl-1">
              <li class="flex gap-2">
                <span class="font-semibold text-base-content w-16 shrink-0">Bridge</span>
                <span>Connect any two corner hexes of the board with a chain of your stones.</span>
              </li>
              <li class="flex gap-2">
                <span class="font-semibold text-base-content w-16 shrink-0">Fork</span>
                <span>
                  Connect any three edges of the board (not counting corners) with a chain of your stones.
                </span>
              </li>
              <li class="flex gap-2">
                <span class="font-semibold text-base-content w-16 shrink-0">Ring</span>
                <span>
                  Form a loop of your stones that completely encloses one or more cells (of any colour).
                </span>
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
