defmodule LegacyWeb.GameChannel do
  use LegacyWeb, :channel

  def join("game:" <> game_id, payload, socket) do
    {:ok, socket}
  end

  def handle_in("play_turn", %{"move" => _} = payload, socket) do
    broadcast socket, "on_play_turn", payload
    {:noreply, socket}
  end
end
