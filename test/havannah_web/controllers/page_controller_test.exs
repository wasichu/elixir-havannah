defmodule HavannahWeb.PageControllerTest do
  use HavannahWeb.ConnCase

  test "GET / redirects to LiveView game", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "havannah-game"
  end
end
