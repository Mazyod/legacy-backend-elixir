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
    result = GameMaster.join_game(:game_master, self(), id)
    |> case do
      :ok ->
        # TODO: push down the game state
        {:ok, socket}
      _ ->
        {:error, %{}}
    end
  end

  @impl true
  def handle_in("open_game", %{"name" => _} = meta, socket) do
    {:ok, id} = GameMaster.create_game(:game_master, meta)
    {:reply, {:ok, id}, socket}
  end

  @impl true
  def handle_in("play_turn", %{"move" => _} = payload, socket) do
    broadcast socket, "on_play_turn", payload
    {:noreply, socket}
  end

  @impl true
  def handle_info(:after_join_lobby, socket) do
    push socket, "on_game_list", GameMaster.game_list(:game_master)
    {:noreply, socket}
  end
end
