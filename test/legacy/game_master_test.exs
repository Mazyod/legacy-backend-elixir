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
    meta = %{"id" => "whatever", "name" => "something"}
    assert GameMaster.create_game(pid, self(), meta) == :ok
    assert GameMaster.game_list(pid) == [meta]
  end

  test "it handles joining nonexistent games", %{pid: pid} do
    assert GameMaster.join_game(pid, self(), "arg3") == :error
  end

  test "it handles joining games", %{pid: pid} do
    # GTH: probably disallow same pid joining twice
    meta = %{"id" => "whatever", "name" => "something"}
    assert GameMaster.create_game(pid, self(), meta) == :ok
    assert GameMaster.join_game(pid, self(), meta["id"]) == :ok
  end

  ## Feature Tests

  test "start a game, then disconnect before it begins", %{pid: pid} do

    Endpoint.subscribe("games:lobby", [link: true])

    {:ok, agent} = Agent.start_link(fn -> :ok end)

    id = "whatever"
    game = %{"id" => id, "name" => "something"}
    # starting a game...
    assert GameMaster.create_game(pid, agent, game) == :ok
    # should add it to the game list
    assert GameMaster.game_list(pid) == [game]
    # and broadcast to the games lobby the new game
    assert_received %{event: "game_opened", payload: ^game}

    # when the host disconnects
    assert Agent.stop(agent) == :ok
    # the game is removed from the listing
    assert GameMaster.game_list(pid) == []
    # and a game closed event is broadcasted to the lobby
    assert_received %{event: "game_closed", payload: %{"id" => ^id}}

    Endpoint.unsubscribe("games:lobby")
  end

  test "start a game, guest joins, then guest disconnects", %{pid: pid} do
    # TODO: write test
  end

  test "start a game, guest joins, both players disconnect", %{pid: pid} do
    # TODO: write test
  end

end
