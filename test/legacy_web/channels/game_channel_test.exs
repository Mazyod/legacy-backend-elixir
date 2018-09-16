defmodule LegacyWeb.GameChannelTest do
  use LegacyWeb.ChannelCase

  alias LegacyWeb.GameChannel


  setup %{} do
    {:ok, %{}}
  end

  test "everything", %{} do
    # initialize two sockets/channels/players
    {:ok, _, lobby_socket1} = socket("maz", %{})
    |> subscribe_and_join(GameChannel, "games:lobby")

    {:ok, _, lobby_socket2} = socket("jim", %{})
    |> subscribe_and_join(GameChannel, "games:lobby")

    # two sockets worth of game lists
    assert_push "on_game_list", %{"game_list" => []}
    assert_push "on_game_list", %{"game_list" => []}

    # open a game
    ref = push lobby_socket1, "open_game", %{"name" => "Trolololo"}
    assert_reply ref, :ok, %{"id" => id}

    ref = leave lobby_socket1
    assert_reply ref, :ok, _

    # host joins his game
    {:ok, _, game_socket1} = socket("maz", %{})
    |> subscribe_and_join(GameChannel, "games:" <> id)

    # assert broadcast
    assert_broadcast "on_game_opened", %{"id" => ^id, "name" => _}

    # guest decides to join
    ref = leave lobby_socket2
    assert_reply ref, :ok, _

    {:ok, _, game_socket2} = socket("jim", %{})
    |> subscribe_and_join(GameChannel, "games:" <> id)

    assert_broadcast "on_game_started", %{}
    assert_broadcast "on_game_started", %{}

    # send some moves
    turn = %{"data" => [1, 2, 3]}
    _ref = push game_socket1, "send_message", turn
    # only the other player receives the message
    assert_push "on_message", ^turn
    refute_push "on_message", ^turn

    # cleanup
    ref1 = leave game_socket1
    ref2 = leave game_socket2

    assert_reply ref1, :ok, _
    assert_reply ref2, :ok, _
  end
end
