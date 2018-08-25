# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Time resolution: reduced in test config for faster tests
config :legacy, Legacy.GameState,
  interval_resolution: :seconds

# Configures the endpoint
config :legacy, LegacyWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "lq/ip2iXlFjLNClhvxtYu3e0T/6lAtBc4mnNjxi9ezxZ2lfw6XOwuz2idqjUFjCk",
  render_errors: [view: LegacyWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Legacy.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
