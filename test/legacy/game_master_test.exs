defmodule Legacy.GameMasterTest do
  use ExUnit.Case

  alias Legacy.GameMaster


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

end
