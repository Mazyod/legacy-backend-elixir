defmodule LegacyWeb.Router do
  use LegacyWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api/v1", LegacyWeb do
    pipe_through :api

    get "/health", APIController, :health
  end
end
