defmodule HavannahWeb.ConnCase do
  @moduledoc "Shared Phoenix connection setup. This application has no database or SQL sandbox."

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint HavannahWeb.Endpoint

      use HavannahWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import HavannahWeb.ConnCase
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
