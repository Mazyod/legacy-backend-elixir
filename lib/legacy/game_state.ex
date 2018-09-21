defmodule Legacy.GameState do
  use GenServer

  @broadcast_topic "games:lobby"


  ### Const

  defp config(key), do: Application.get_env(:legacy, __MODULE__)[key]
  # evaluates to a function object
  defp interval_resolution do
    config(:interval_resolution)
    |> case do
      :seconds -> &:timer.seconds/1
      :milliseconds -> &(&1 * 2)
    end
  end


  ## Server

  def start(meta),
  do: GenServer.start(__MODULE__, meta)

  def start_link(meta),
  do: GenServer.start_link(__MODULE__, meta)

  def add_player(pid, player_pid),
  do: GenServer.call(pid, {:add_player, player_pid})


  ## Client

  @impl true
  def init(meta) do
    # TODO: add expiry timer, if no one ever joins this process
    {:ok, %{
      meta: meta,
      players: [],
      grace_timer: nil}}
  end

  @impl true
  def handle_call({:add_player, pid}, _from, state) do
    {result, state} =
      case state.players do
        [] ->
          state = %{state | players: [pid]}
          broadcast_game_opened(state)
          {:game_opened, state}
        [_] = players ->
          state = %{state | players: players ++ [pid]}
          broadcast_game_closed(state)
          broadcast_game_started(state)
          {:game_closed, state}
        [p1, p2] ->
          cond do
            Process.alive?(p1) == false ->
              state = %{state | players: [pid, p2]}
              broadcast_player_reconnected(state)
              {:player_rejoined, state}
            Process.alive?(p2) == false ->
              state = %{state | players: [p1, pid]}
              broadcast_player_reconnected(state)
              {:player_rejoined, state}
            true ->
              {:error, state}
          end
      end

    unless result == :error do
      Process.monitor(pid)
    end

    {:reply, result, state}
  end

  ## Process monitor

  @impl true
  def handle_info(:grace_timer_over, %{players: [p1, p2]} = state) do
    if Process.alive?(p1) and Process.alive?(p2) do
      {:noreply, state}
    else
      broadcast_game_ended(state)
      {:stop, {:shutdown, :normal}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    case state do
      %{players: [_]} ->
        # game hasn't started, so still in game list
        broadcast_game_closed(state)
        {:stop, {:shutdown, :normal}, state}
      %{players: [p1, p2]} ->
        if Process.alive?(p1) or Process.alive?(p2) do
          # player disconnected. Give them a chance to reconnect
          broadcast_player_disconnected(state)
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
    grace_period = interval_resolution().(30)
    timer = Process.send_after(self(), :grace_timer_over, grace_period)
    %{state | grace_timer: timer}
  end

  # broadcasting
  defp broadcast(event, payload) do
    LegacyWeb.Endpoint.broadcast! @broadcast_topic, event, payload
  end

  defp broadcast_game_opened(%{meta: meta}) do
    broadcast("on_game_opened", meta)
  end

  defp broadcast_game_closed(%{meta: %{"id" => id}}) do
    broadcast("on_game_closed", %{"id" => id})
  end

  defp broadcast_game_event(%{players: players}, event) do
    players |> Enum.each(fn player ->
      send player, {:on_event, event}
    end)
  end

  defp broadcast_game_started(state) do
    broadcast_game_event(state, "on_game_started")
  end

  defp broadcast_player_disconnected(state) do
    broadcast_game_event(state, "on_player_disconnected")
  end

  defp broadcast_player_reconnected(state) do
    broadcast_game_event(state, "on_player_reconnected")
  end

  defp broadcast_game_ended(state) do
    broadcast_game_event(state, "on_game_ended")
  end

end
