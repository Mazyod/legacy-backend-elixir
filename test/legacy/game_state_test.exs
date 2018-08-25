defmodule Legacy.GameStateTest do
  use ExUnit.Case

  alias Legacy.GameState

  @meta %{"id" => "blah-blah", "name" => "say"}

  setup %{} do
    {:ok, pid} = GameState.start_link(@meta)
    {:ok, %{pid: pid}}
  end

  test "it is alive", %{pid: pid} do
    assert Process.alive?(pid)
  end

  test "it can add max two players", %{pid: pid} do
    # TODO: enforce distinct pids
    assert GameState.add_player(pid, self()) == :game_opened
    assert GameState.add_player(pid, self()) == :game_closed
    assert GameState.add_player(pid, self()) == :error
  end
end
