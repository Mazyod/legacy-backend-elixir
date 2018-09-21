defmodule LegacyWeb.GameChannel do
  use LegacyWeb, :channel

  alias Legacy.GameMaster


  @impl true
  def join("games:lobby", _payload, socket) do
    send(self(), :after_join_lobby)
    {:ok, socket}
  end

  # either create or join an existing game
  @impl true
  def join("games:" <> id, _payload, socket) do
    GameMaster.join_game(:game_master, self(), id)
    |> case do
      :ok ->
        {:ok, socket}
      _ ->
        {:error, %{}}
    end
  end

  @impl true
  def handle_in("open_game", %{"name" => _} = meta, socket) do
    {:ok, id} = GameMaster.create_game(:game_master, meta)
    {:reply, {:ok, %{"id" => id}}, socket}
  end

  @impl true
  def handle_in("send_message", %{"data" => _} = payload, socket) do
    broadcast socket, "on_message", %{payload: payload, sender: socket.channel_pid}
    {:noreply, socket}
  end

  @impl true
  def handle_info(:after_join_lobby, socket) do
    game_list = GameMaster.game_list(:game_master)
    push socket, "on_game_list", %{"game_list" => game_list}
    {:noreply, socket}
  end

  @impl true
  def handle_info({:on_event, event}, socket) do
    push socket, event, %{}
    {:noreply, socket}
  end

  intercept ["on_message"]
  def handle_out("on_message" = event, %{payload: payload, sender: sender}, socket) do
    unless socket.channel_pid == sender do
      push socket, event, payload
    end
    {:noreply, socket}
  end
end
