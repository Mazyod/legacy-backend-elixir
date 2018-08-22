defmodule LegacyWeb.PageController do
  use LegacyWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
