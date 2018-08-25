defmodule Legacy.GameMaster do
  @moduledoc """
  Game Master: the process responsible for registering and maintaining all
  available game states.

  TODO: If a host creates a game, and fails to join, it will list an empty game
  """
  use GenServer

  alias Legacy.GameState


  ## Client

  def start_link(opts \\ []),
  do: GenServer.start_link(__MODULE__, :ok, opts)

  def game_list(pid),
  do: GenServer.call(pid, :game_list)

  def create_game(pid, %{"name" => _} = meta),
  do: GenServer.call(pid, {:create_game, meta})

  def join_game(pid, player_pid, id) when is_binary(id),
  do: GenServer.call(pid, {:join_game, player_pid, id})


  ## Server

  @impl true
  def init(:ok) do
    {:ok, %{
      pending_games: %{},
      running_games: %{}}}
  end

  @impl true
  def handle_call(:game_list, _from, state) do
    game_list = state.pending_games
    |> Map.values()
    |> Enum.map(&(&1.meta))

    {:reply, game_list, state}
  end

  @impl true
  def handle_call({:create_game, meta}, _from, state) do
    id = :crypto.strong_rand_bytes(15) |> Base.encode16()
    meta = Map.put(meta, "id", id)
    {:ok, game_state} = GameState.start(meta)

    _ref = Process.monitor(game_state)
    game = %{meta: meta, pid: game_state}
    games = Map.put(state.pending_games, meta["id"], game)
    {:reply, {:ok, id}, %{state | pending_games: games}}
  end

  @impl true
  def handle_call({:join_game, pid, id}, _from, state) do
    game = state.pending_games[id] || state.running_games[id]
    {result, state} =
      case game do
        nil ->
          {:error, state}
        game ->
          case GameState.add_player(game.pid, pid) do
            :game_opened ->
              {:ok, state}
            :player_rejoined ->
              {:ok, state}
            :game_closed ->
              {:ok, move_game_to_running_games(game, state)}
            :error ->
              {:error, state}
          end
      end
    {:reply, result, state}
  end

  ## Process monitor

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, remove_game(pid, state)}
  end

  ## Private functions

  defp move_game_to_running_games(game, state) do
    id = game.meta["id"]
    pending_games = Map.delete(state.pending_games, id)
    running_games = Map.put(state.running_games, id, game)

    %{state |
      pending_games: pending_games,
      running_games: running_games}
  end

  defp remove_game(pid, state) do
    filter = fn map ->
      map
      |> Enum.filter(fn {_id, game} ->
        pid != game.pid
      end)
      |> Enum.into(%{})
    end

    %{state |
      pending_games: filter.(state.pending_games),
      running_games: filter.(state.running_games)}
  end
end
