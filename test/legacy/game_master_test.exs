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

    host_pid = dummy_pid()

    game = %{"name" => "something"}
    # creating a game...
    {:ok, id} = GameMaster.create_game(pid, game)
    game = Map.put(game, "id", id)

    # when the host joins...
    assert GameMaster.join_game(pid, host_pid, id)
    # ...it broadcasts to the games lobby the new game
    assert_received %{event: "on_game_opened", payload: ^game}
    # ...and then disconnects
    assert Process.exit(host_pid, :kill)
    # due to some message relay delay, we need to wait for the down message
    :erlang.trace(pid, true, [:receive])
    assert_receive({:trace, ^pid, :receive, {:DOWN, _, _, _, _}})
    # the game is removed from the listing
    assert GameMaster.game_list(pid) == []
    # the game closed event is broadcasted to the lobby
    assert_receive %{event: "on_game_closed", payload: %{"id" => ^id}}

    Endpoint.unsubscribe("games:lobby")
  end

  test "start a game, guest joins, then guest disconnects", %{pid: pid} do

    Endpoint.subscribe("games:lobby", [link: true])

    host_pid = dummy_pid()
    guest_pid = dummy_pid()

    :erlang.trace(host_pid, true, [:receive])

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
    assert_receive %{event: "on_game_closed", topic: "games:lobby"}
    assert_receive {:trace, ^host_pid, :receive, {:on_event, "on_game_started"}}

    # if a player disconnects for a bit...
    assert Process.exit(guest_pid, :kill)
    # we don't immediately lose faith
    assert_receive {:trace, ^host_pid, :receive, {:on_event, "on_player_disconnected"}}
    refute_received %{event: "on_game_ended"}

    # if the player rejoins...
    guest_pid = dummy_pid()
    assert GameMaster.join_game(pid, guest_pid, id) == :ok
    # we get notified about that as well
    assert_receive {:trace, ^host_pid, :receive, {:on_event, "on_player_reconnected"}}

    # if a player disconnects ...
    assert Process.exit(guest_pid, :kill)
    # we disconnect after sufficient time has passed
    assert_receive {:trace, ^host_pid, :receive, {:on_event, "on_player_disconnected"}}
    assert_receive {:trace, ^host_pid, :receive, {:on_event, "on_game_ended"}}, 200

    Endpoint.unsubscribe("games:lobby")
    Endpoint.unsubscribe("games:" <> id)
  end

  test "start a game, guest joins, both players disconnect", %{pid: _pid} do
    # TODO: write test
  end

  ## helpers
  # TODO: Find a better common place

  defp dummy_pid do
    spawn(fn ->
      loop = fn loop ->
        receive do
          _ -> :ok
        end
        loop.(loop)
      end
      loop.(loop)
    end)
  end

end
