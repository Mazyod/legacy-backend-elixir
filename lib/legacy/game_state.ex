defmodule GameState do
  use GenServer

  @broadcast_topic "games:lobby"


  ## Server

  def start(meta),
  do: GenServer.start(__MODULE__, meta)

  def add_player(pid, player_pid),
  do: GenServer.call(pid, {:add_player, player_pid})


  ## Client

  @impl true
  def init(meta) do
    {:ok, %{
      meta: meta,
      players: [],
      grace_timer: nil}}
  end

  @impl true
  def handle_call({:add_player, pid}, _from, state) do
    {result, players} =
      case state.players do
        [] ->
          broadcast_game_opened(state.meta)
          {:game_opened, [pid]}
        [_] ->
          broadcast_game_closed(state.meta["id"])
          broadcast_game_started(state.meta["id"])
          {:game_closed, state.players ++ [pid]}
        [p1, p2] ->
          cond do
            Process.alive?(p1) == false ->
              {:player_rejoined, [pid, p2]}
            Process.alive?(p2) == false ->
              {:player_rejoined, [p1, pid]}
            true ->
              {:error, state.players}
          end
          {:error, state.players}
      end

    unless result == :error do
      Process.monitor(pid)
    end

    {:reply, result, %{state | players: players}}
  end

  ## Process monitor

  @impl true
  def handle_info(:grace_timer_over, %{players: [p1, p2]} = state) do
    if Process.alive?(p1) and Process.alive?(p2) do
      {:noreply, state}
    else
      broadcast_game_ended(state.meta["id"])
      {:stop, {:shutdown, :normal}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    case state do
      %{players: [_]} ->
        # game hasn't started, so still in game list
        broadcast_game_closed(state.meta["id"])
        {:stop, {:shutdown, :normal}, state}
      %{players: [p1, p2]} ->
        if Process.alive?(p1) or Process.alive?(p2) do
          # player disconnected. Give them a chance to reconnect
          {:noreply, start_grace_timer(state)}
        else
          # both players gone! Let's just give up
          {:stop, {:shutdown, :normal}, state}
        end
    end
  end

  ## Private functions

  # if a grace timer is established, cancel it before setting the new one
  defp start_grace_timer(%{grace_timer: timer_ref} = state)
  when is_reference(timer_ref)
  do
    Process.cancel_timer(timer_ref)
    start_grace_timer(%{state | grace_timer: nil})
  end

  defp start_grace_timer(state) do
    seconds = 1_000 # TODO: use interval_resolution from config
    timer = Process.send_after(self(), :grace_timer_over, 30 * seconds)
    %{state | grace_timer: timer}
  end

  # broadcasting
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

end
