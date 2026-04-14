defmodule HavannahWeb.PageControllerTest do
  use HavannahWeb.ConnCase

  test "GET / renders the lobby", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Havannah"
    assert html_response(conn, 200) =~ "Create Game"
  end
end
