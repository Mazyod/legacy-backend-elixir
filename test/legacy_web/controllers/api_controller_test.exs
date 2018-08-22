defmodule LegacyWeb.APIControllerTest do
  use LegacyWeb.ConnCase

  test "GET /api/v1/health", %{conn: conn} do
    conn = get conn, "/api/v1/health"
    assert json_response(conn, 200) == %{"status" => "ok"}
  end
end
