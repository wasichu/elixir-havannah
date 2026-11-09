defmodule HavannahWeb.LobbyLiveTest do
  use HavannahWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Havannah.GameServer

  test "creates a human game from the lobby", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#mode-human-vs-human[checked]")
    view |> element("#create-game") |> render_click()
    {path, _flash} = assert_redirect(view)
    assert "/game/" <> id = path
    assert {:ok, %{mode: :human_vs_human}} = GameServer.get_state(id)
    on_exit(fn -> stop_game(id) end)
  end

  test "selects AI mode and ignores invalid mode payloads", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    view |> element("#mode-human-vs-ai") |> render_click()
    assert has_element?(view, "#mode-human-vs-ai[checked]")
    render_click(view, "set_mode", %{"mode" => "not-a-mode"})
    render_click(view, "set_mode", %{})
    assert has_element?(view, "#mode-human-vs-ai[checked]")
    view |> element("#create-game") |> render_click()
    {path, _flash} = assert_redirect(view)
    assert "/game/" <> id = path
    assert {:ok, %{mode: :human_vs_ai}} = GameServer.get_state(id)
    on_exit(fn -> stop_game(id) end)
  end

  defp stop_game(id) do
    case Registry.lookup(Havannah.GameRegistry, id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(Havannah.GameSupervisor, pid)
      [] -> :ok
    end
  end
end
