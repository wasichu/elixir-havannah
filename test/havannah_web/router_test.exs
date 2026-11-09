defmodule HavannahWeb.RouterTest do
  use HavannahWeb.ConnCase

  test "GET / renders the lobby", %{conn: conn} do
    conn = get(conn, ~p"/")
    document = conn |> html_response(200) |> LazyHTML.from_document()
    assert document |> LazyHTML.query("#create-game") |> Enum.to_list() != []
  end
end
