defmodule Legacy.GameMaster do
  use GenServer


  ## Client

  def start_link, do: GenServer.start_link(__MODULE__, :ok)


  ## Server

  def init(:ok) do
    {:ok, %{}}
  end

end
