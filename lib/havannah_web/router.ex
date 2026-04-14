defmodule HavannahWeb.Router do
  use HavannahWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HavannahWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :ensure_session_id
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", HavannahWeb do
    pipe_through :browser

    live "/", LobbyLive
    live "/game/:id", GameLive
  end

  # Seed a persistent session ID so users keep their player slot across
  # page refreshes within the same browser session.
  defp ensure_session_id(conn, _opts) do
    if Plug.Conn.get_session(conn, :session_id) do
      conn
    else
      id = :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
      Plug.Conn.put_session(conn, :session_id, id)
    end
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:havannah, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HavannahWeb.Telemetry
    end
  end
end
