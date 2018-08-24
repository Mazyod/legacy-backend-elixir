defmodule LegacyWeb.GameChannelTest do
  use LegacyWeb.ChannelCase

  alias LegacyWeb.GameChannel

  setup do
    {:ok, _, socket} =
      socket("user_id", %{some: :assign})
      |> subscribe_and_join(GameChannel, "game:some_id")

    {:ok, socket: socket}
  end

  test "it broadcasts play turn messages", %{socket: socket} do
    move = %{"block" => "xyz", "steps" => [1, 2, 3]}
    payload = %{"move" => move}

    _ref = push socket, "play_turn", payload
    assert_broadcast "on_play_turn", ^payload
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from! socket, "broadcast", %{"some" => "data"}
    assert_push "broadcast", %{"some" => "data"}
  end
end
