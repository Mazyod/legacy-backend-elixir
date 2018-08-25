defmodule Legacy.GameMasterTest do
  use ExUnit.Case

  alias Legacy.GameMaster
  alias LegacyWeb.Endpoint


  setup %{} do
    {:ok, pid} = GameMaster.start_link
    {:ok, %{pid: pid}}
  end

  ## Basic tests

  test "it is alive", %{pid: pid} do
    Process.alive? pid
  end

  test "it retrieves game list", %{pid: pid} do
    assert GameMaster.game_list(pid) == []
  end

  test "it can create games", %{pid: pid} do
    meta = %{"name" => "something"}
    {:ok, id} = GameMaster.create_game(pid, meta)
    assert GameMaster.game_list(pid) == [Map.put(meta, "id", id)]
  end

  test "it handles joining nonexistent games", %{pid: pid} do
    assert GameMaster.join_game(pid, self(), "arg3") == :error
  end

  test "it handles joining games", %{pid: pid} do
    meta = %{"name" => "something"}
    {:ok, id} = GameMaster.create_game(pid, meta)
    assert GameMaster.join_game(pid, self(), id) == :ok
  end

  ## Feature Tests

  # TODO: notice how the game list is updated immediately, but the game opened
  # event is only broadcasted later. Game list should also be updated iff the
  # host joins.
  # TODO: this test is flaky due to player pid termination message takes time
  # to propagate all the way to GameMaster.
  test "start a game, then disconnect before it begins", %{pid: pid} do

    Endpoint.subscribe("games:lobby", [link: true])

    {:ok, agent} = Agent.start_link(fn -> :ok end)

    game = %{"name" => "something"}
    # creating a game...
    {:ok, id} = GameMaster.create_game(pid, game)
    game = Map.put(game, "id", id)

    # when the host joins...
    assert GameMaster.join_game(pid, agent, id)
    # ...it broadcasts to the games lobby the new game
    assert_received %{event: "game_opened", payload: ^game}
    # ...and then disconnects
    assert Agent.stop(agent) == :ok
    # the game closed event is broadcasted to the lobby
    assert_receive %{event: "game_closed", payload: %{"id" => ^id}}
    # the game is removed from the listing
    assert GameMaster.game_list(pid) == []

    Endpoint.unsubscribe("games:lobby")
  end

  test "start a game, guest joins, then guest disconnects", %{pid: pid} do

    Endpoint.subscribe("games:lobby", [link: true])

    {:ok, host_pid} = Agent.start(fn -> :ok end)
    {:ok, guest_pid} = Agent.start(fn -> :ok end)

    game = %{"name" => "whatever"}
    # starting a game...
    {:ok, id} = GameMaster.create_game(pid, game)
    Endpoint.subscribe("games:" <> id, [link: true])

    # host joins...
    assert GameMaster.join_game(pid, host_pid, id) == :ok
    # guest joins...
    assert GameMaster.join_game(pid, guest_pid, id) == :ok
    # game disappears from the list
    assert GameMaster.game_list(pid) == []
    # with the broadcasts
    assert_receive %{event: "game_closed", topic: "games:lobby"}
    assert_receive %{event: "game_started", topic: "games:" <> ^id}

    # if a player disconnects for a bit...
    assert Agent.stop(guest_pid) == :ok
    # we don't immediately lose faith
    assert_receive %{event: "player_disconnected"}
    refute_received %{event: "game_ended"}

    # if the player rejoins...
    {:ok, guest_pid} = Agent.start(fn -> :ok end)
    assert GameMaster.join_game(pid, guest_pid, id) == :ok
    # we get notified about that as well
    assert_receive %{event: "player_reconnected"}

    # if a player disconnects ...
    assert Agent.stop(guest_pid) == :ok
    # we disconnect after sufficient time has passed
    assert_receive %{event: "player_disconnected"}
    assert_receive %{event: "game_ended"}, 200

    Endpoint.unsubscribe("games:lobby")
    Endpoint.unsubscribe("games:" <> id)
  end

  test "start a game, guest joins, both players disconnect", %{pid: _pid} do
    # TODO: write test
  end

end
