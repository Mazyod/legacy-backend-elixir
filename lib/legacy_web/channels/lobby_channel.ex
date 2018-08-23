defmodule LegacyWeb.LobbyChannel do
  use LegacyWeb, :channel

  def join("lobby:lobby", payload, socket) do
    {:ok, socket}
  end

  # List available rooms
  def handle_in("list_rooms", _payload, socket) do
    # TODO: grab available rooms from Lobby
    {:reply, {:ok, %{"rooms" => []}}, socket}
  end

  # Open a new room. Requires the name of the room to be given.
  def handle_in("open_room", %{"name" => room_name}, socket) do
    # TODO: open the room in the Lobby GenServer
    {:reply, {:ok, %{}}, socket}
  end

  # Attempt to join the room with the given id
  def handle_in("join_room", %{"id" => room_id}, socket) do
    # TODO: attempt to join the room id on Lobby GenServer
    {:reply, {:ok, %{}}, socket}
  end
end
