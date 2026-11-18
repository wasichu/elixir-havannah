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

  test "human games offer a copy button without displaying the invitation URL", %{
    conn: conn,
    id: id
  } do
    {:ok, view, _html} = live(conn, ~p"/game/#{id}")

    assert has_element?(
             view,
             "#copy-game-link[phx-hook=CopyGameLink][data-path='/game/#{id}']",
             "Copy game link"
           )

    refute has_element?(view, "#havannah-game", "/game/#{id}")
  end

  test "players see moves, make pie decisions, and resign", %{conn: conn, id: id} do
    alice = init_test_session(conn, session_id: "alice")
    bob = init_test_session(build_conn(), session_id: "bob")
    {:ok, first, _html} = live(alice, ~p"/game/#{id}")
    assert has_element?(first, "#cancel-invitation", "Cancel invitation")
    refute has_element?(first, "#resign")
    refute has_element?(first, "#rematch")
    refute has_element?(first, "#hex-0-0[phx-click]")
    {:ok, second, _html} = live(bob, ~p"/game/#{id}")

    refute has_element?(first, "#cancel-invitation")
    refute has_element?(second, "#cancel-invitation")
    assert has_element?(first, "#resign")
    assert has_element?(second, "#resign")
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

  test "cancelling returns all creator tabs to the lobby and invalidates the invitation", %{
    conn: conn,
    id: id,
    game_pid: pid
  } do
    alice = init_test_session(conn, session_id: "alice")
    {:ok, first, _} = live(alice, ~p"/game/#{id}")
    {:ok, other_tab, _} = live(alice, ~p"/game/#{id}")
    monitor = Process.monitor(pid)

    first |> element("#cancel-invitation") |> render_click()

    assert_redirect(first, ~p"/")
    assert_redirect(other_tab, ~p"/")
    assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}
    assert {:error, :not_found} = GameServer.get_state(id)
    assert {:error, {:live_redirect, %{to: "/"}}} = live(build_conn(), ~p"/game/#{id}")
  end

  test "forged resign and rematch events do not end or replace a waiting invitation", %{
    conn: conn,
    id: id
  } do
    {:ok, view, _} = live(conn, ~p"/game/#{id}")
    render_click(view, "resign", %{})
    render_click(view, "rematch", %{})
    assert has_element?(view, "#cancel-invitation")
    assert {:ok, %{status: :waiting, game: %{winner: nil}}} = GameServer.get_state(id)
    refute_redirected(view)
  end

  test "a stale cancel event cannot cancel a match after the opponent joins", %{
    conn: conn,
    id: id
  } do
    {:ok, view, _} = live(init_test_session(conn, session_id: "alice"), ~p"/game/#{id}")
    GameServer.join(id, "bob")
    render_click(view, "cancel_invitation", %{})
    assert has_element?(view, "#resign")
    refute has_element?(view, "#cancel-invitation")
    assert {:ok, %{status: :playing}} = GameServer.get_state(id)
    refute_redirected(view)
  end

  test "rematch after resignation creates a fresh invitation with a different link", %{
    conn: conn,
    id: id
  } do
    {:ok, view, _} = live(init_test_session(conn, session_id: "alice"), ~p"/game/#{id}")
    GameServer.join(id, "bob")
    assert :ok = GameServer.resign(id, "alice")
    view |> element("#rematch") |> render_click()
    {path, _flash} = assert_redirect(view)
    assert "/game/" <> new_id = path
    refute new_id == id
    assert {:ok, %{mode: :human_vs_human, status: :waiting}} = GameServer.get_state(new_id)
    [{pid, _}] = Registry.lookup(Havannah.GameRegistry, new_id)
    on_exit(fn -> DynamicSupervisor.terminate_child(Havannah.GameSupervisor, pid) end)
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
    refute has_element?(spectator, "#cancel-invitation")
    render_click(spectator, "cancel_invitation", %{})
    render_click(spectator, "rematch", %{})
    refute_redirected(spectator)
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
