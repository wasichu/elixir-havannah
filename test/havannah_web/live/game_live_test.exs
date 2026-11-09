defmodule HavannahWeb.GameLiveTest do
  use HavannahWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Havannah.GameServer

  setup do
    id = "live-#{System.unique_integer([:positive])}"
    pid = start_supervised!({GameServer, {id, :human_vs_human}})
    %{id: id, game_pid: pid}
  end

  test "missing games redirect to the lobby", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/game/missing")
  end

  test "players see moves, make pie decisions, and resign", %{conn: conn, id: id} do
    alice = init_test_session(conn, session_id: "alice")
    bob = init_test_session(build_conn(), session_id: "bob")
    {:ok, first, _html} = live(alice, ~p"/game/#{id}")
    refute has_element?(first, "#hex-0-0[phx-click]")
    {:ok, second, _html} = live(bob, ~p"/game/#{id}")

    assert has_element?(first, "#hex-0-0[phx-click=place]")
    first |> element("#hex-0-0") |> render_click()
    assert has_element?(second, "#hex-0-0.hex-blue.hex-last-move")
    refute has_element?(second, "#havannah-game span", "Last (")
    assert has_element?(second, "#pie-decision")
    second |> element("#pie-swap") |> render_click()
    refute has_element?(second, "#pie-decision")
    assert has_element?(first, "#hex-1-0[phx-click=place]")
    first |> element("#hex-1-0") |> render_click()
    assert has_element?(second, "#hex-1-0.hex-red.hex-last-move")
    refute has_element?(second, "#hex-0-0.hex-last-move")
    assert has_element?(second, "#havannah-board > polygon:last-child#hex-1-0")
    first |> element("#confirm-resign") |> render_click()
    assert has_element?(second, "#rematch")
    assert {:ok, %{game: %{winner: :blue, win_reason: :resignation}}} = GameServer.get_state(id)
  end

  test "invalid browser payloads leave the process and game intact", %{conn: conn, id: id} do
    conn = init_test_session(conn, session_id: "alice")
    {:ok, view, _html} = live(conn, ~p"/game/#{id}")
    GameServer.join(id, "bob")
    render_click(view, "place", %{"q" => "bad", "r" => "0"})
    render_click(view, "place", %{"q" => nil})
    render_click(view, "pie_decision", %{"choice" => "unexpected"})
    assert has_element?(view, "#havannah-board")
    assert {:ok, %{game: %{phase: :opening, last_move: nil}}} = GameServer.get_state(id)
  end

  test "spectators cannot act and a session keeps its slot on reconnect", %{conn: conn, id: id} do
    GameServer.join(id, "alice")
    GameServer.join(id, "bob")
    {:ok, spectator, _} = live(init_test_session(conn, session_id: "carol"), ~p"/game/#{id}")
    refute has_element?(spectator, "#hex-0-0[phx-click]")
    refute has_element?(spectator, "#resign")
    render_click(spectator, "place", %{"q" => "0", "r" => "0"})
    assert {:ok, %{game: %{last_move: nil}}} = GameServer.get_state(id)
    {:ok, alice, _} = live(init_test_session(build_conn(), session_id: "alice"), ~p"/game/#{id}")
    assert has_element?(alice, "#hex-0-0[phx-click=place]")
  end

  test "obsolete ticks are ignored and updates keep one timer", %{conn: conn, id: id} do
    {:ok, view, _} = live(init_test_session(conn, session_id: "alice"), ~p"/game/#{id}")
    GameServer.join(id, "bob")
    render(view)
    old_ref = :sys.get_state(view.pid).socket.assigns.tick_ref
    assert is_reference(old_ref)
    GameServer.place(id, "alice", {0, 0})
    render(view)
    new_ref = :sys.get_state(view.pid).socket.assigns.tick_ref
    assert is_reference(new_ref)
    refute old_ref == new_ref
    assert Process.read_timer(old_ref) == false
    send(view.pid, {:timeout, old_ref, :tick})
    render(view)
    assert :sys.get_state(view.pid).socket.assigns.tick_ref == new_ref
  end
end
