defmodule Legacy.GameMaster do
  use GenServer

  @broadcast_topic "games:lobby"


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
    game = %{meta: meta, players: [host_pid], grace_timer: nil}
    games = Map.put(state.games, meta["id"], game)

    broadcast_game_opened(meta)

    {:reply, :ok, %{state | games: games}}
  end

  @impl true
  def handle_call({:join_game, guest_pid, id}, _from, state) do
    {result, games} =
      case state.games[id] do
        %{players: [host_pid]} = game ->
          _ref = Process.monitor(guest_pid)
          new_game = %{game | players: [host_pid, guest_pid]}
          broadcast_game_closed(id)
          broadcast_game_started(id)
          {:ok, Map.put(state.games, id, new_game)}
        _ ->
          {:error, state.games}
      end
    {:reply, result, %{state | games: games}}
  end

  ## Process monitor

  @impl true
  def handle_info({:grace_period_over, %{"id" => id}}, state) do
    games =
      case state.games[id] do
        nil ->
          # game not even found ¯\_(ツ)_/¯
          state.games
        %{players: [p1, p2]} ->
          if Process.alive?(p1) and Process.alive?(p2) do
            state.games
          else
            broadcast_game_ended(id)
            Map.delete(state.games, id)
          end
      end
    {:noreply, %{state | games: games}}
  end

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
        {id, %{players: [p1, p2]} = game} ->
          if Process.alive?(p1) or Process.alive?(p2) do
            # player disconnected. Give them a chance to reconnect
            game = start_grace_period(game)
            Map.put(state.games, id, game)
          else
            # both players gone! Let's just give up
            Map.delete(state.games, id)
          end
      end
    {:noreply, %{state | games: games}}
  end

  ## Private functions

  defp broadcast(event, payload) do
    LegacyWeb.Endpoint.broadcast! @broadcast_topic, event, payload
  end

  defp broadcast_game_opened(meta) do
    broadcast("game_opened", meta)
  end

  defp broadcast_game_closed(id) do
    broadcast("game_closed", %{"id" => id})
  end

  defp broadcast_game_event(id, event) do
    LegacyWeb.Endpoint.broadcast! "games:" <> id, event, %{}
  end

  defp broadcast_game_started(id) do
    broadcast_game_event(id, "game_started")
  end

  defp broadcast_game_ended(id) do
    broadcast_game_event(id, "game_ended")
  end

  # if a grace timer is established, cancel it before setting the new one
  defp start_grace_period(%{grace_timer: timer_ref} = game)
  when is_reference(timer_ref)
  do
    Process.cancel_timer(timer_ref)
    start_grace_period(%{game | grace_timer: nil})
  end

  defp start_grace_period(game) do
    seconds = 1_000 # use interval_resolution from config
    timer = Process.send_after(self(), :grace_period_over, %{game: game}, 30 * seconds)
    %{game | grace_timer: timer}
  end

end
