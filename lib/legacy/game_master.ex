defmodule Legacy.GameMaster do
  use GenServer


  ## Client

  def start_link, do: GenServer.start_link(__MODULE__, :ok)

  def game_list(pid),
  do: GenServer.call(pid, :game_list)

  def create_game(pid, host_pid, %{"id" => _id} = meta),
  do: GenServer.call(pid, {:create_game, host_pid, meta})

  def join_game(pid, guest_pid, id) when is_binary(id),
  do: GenServer.call(pid, {:join_game, guest_pid, id})


  ## Server

  @impl true
  def init(:ok) do
    {:ok, %{games: %{}}}
  end

  @impl true
  def handle_call(:game_list, _from, state) do
    game_list = state.games
    |> Map.values()
    |> Enum.filter(fn %{players: players} ->
      length(players) == 1
    end)
    |> Enum.map(fn game ->
      game.meta
    end)

    {:reply, game_list, state}
  end

  @impl true
  def handle_call({:create_game, host_pid, meta}, _from, state) do
    _ref = Process.monitor(host_pid)
    game = %{meta: meta, players: [host_pid]}
    games = Map.put(state.games, meta["id"], game)
    {:reply, :ok, %{state | games: games}}
  end

  @impl true
  def handle_call({:join_game, guest_pid, id}, _from, state) do
    {result, games} =
      case state.games[id] do
        %{players: [host_pid]} = game ->
          _ref = Process.monitor(guest_pid)
          new_game = %{game | players: [host_pid, guest_pid]}
          {:ok, Map.put(state.games, id, new_game)}
        _ ->
          {:error, state.games}
      end
    {:reply, result, %{state | games: games}}
  end

  ## Process monitor

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    game_tuple = state.games
    |> Enum.find(fn {_id, game} ->
      pid in game.players
    end)

    games =
      case game_tuple do
        nil ->
          # game not even found ¯\_(ツ)_/¯
          state.games
        {id, %{players: [_]}} ->
          # game hasn't started, so still in game list
          broadcast_game_closed(id)
          Map.delete(state.games, id)
        {id, _} ->
          # player disconnected. Give them a change to reconnect
          start_grace_period(id)
          state.games
      end
    {:noreply, %{state | games: games}}
  end

  ## Private functions

  defp broadcast_game_opened(meta) do
    # TODO: broadcast game opened
    :ok
  end

  defp broadcast_game_closed(id) do
    # TODO: broadcast game closed
    :ok
  end

  defp start_grace_period(id) do
    # TODO: schedule timer to end the game when grace period is over
    :ok
  end

end
