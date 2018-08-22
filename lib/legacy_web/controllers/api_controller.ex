defmodule LegacyWeb.APIController do
  use LegacyWeb, :controller

  def health(conn, _params) do
    json conn, %{"status" => "ok"}
  end
end
