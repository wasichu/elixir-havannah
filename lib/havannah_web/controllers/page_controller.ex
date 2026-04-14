defmodule HavannahWeb.PageController do
  use HavannahWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
