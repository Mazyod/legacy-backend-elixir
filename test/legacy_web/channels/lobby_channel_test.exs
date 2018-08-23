defmodule LegacyWeb.LobbyChannelTest do
  use LegacyWeb.ChannelCase

  alias LegacyWeb.LobbyChannel

  setup do
    {:ok, _, socket} =
      socket("user_id", %{some: :assign})
      |> subscribe_and_join(LobbyChannel, "lobby:lobby")

    {:ok, socket: socket}
  end

  test "list rooms returns available rooms", %{socket: socket} do
    ref = push socket, "list_rooms", %{}
    # TODO: test with some dummy rooms available
    assert_reply ref, :ok, %{"rooms" => []}
  end

  test "open room creates a new room", %{socket: socket} do
    ref = push socket, "open_room", %{"name" => "test room"}
    assert_reply ref, :ok, %{}
    # TODO: check for room on Lobby GenServer
  end

  test "join available room flow", %{socket: socket} do
    # Given: we have an available room
    # TODO: prepare an available room
    # When: the user attempts to join that room
    ref = push socket, "join_room", %{"id" => "TODO"}
    # Then: we get matched to a game session
    assert_reply ref, :ok, %{}
    # TODO: assert we get the game channel id
  end
end
