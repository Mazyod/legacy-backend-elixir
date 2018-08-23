defmodule Legacy.GameMasterTest do
  use ExUnit.Case

  alias Legacy.GameMaster
  

  setup %{} do
    {:ok, pid} = GameMaster.start_link
    {:ok, %{pid: pid}}
  end

  test "it is alive", %{pid: pid} do
    Process.alive? pid
  end

end
