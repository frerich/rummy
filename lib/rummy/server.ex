defmodule Rummy.Server do
  use GenServer, restart: :transient

  alias Rummy.Game.Session
  alias Phoenix.PubSub

  def start() do
    id = generate_server_id()

    case DynamicSupervisor.start_child(
           Rummy.Server.Supervisor,
           {__MODULE__, server_id: id, name: via_name(id)}
         ) do
      {:ok, _pid} ->
        {:ok, id}

      other ->
        other
    end
  end

  def add_player(id, player_name) do
    result = GenServer.call(via_name(id), {:add_player, player_name})

    with {:ok, player} <- result do
      PubSub.subscribe(Rummy.PubSub, topic(id))
      Rummy.ProcessMonitor.watch(self(), fn _reason -> remove_player(id, player.id) end)
    end

    result
  end

  def remove_player(id, player_id) do
    GenServer.call(via_name(id), {:remove_player, player_id})
  end

  def pick_tile(id) do
    GenServer.call(via_name(id), :pick_tile)
  end

  def move_tile(id, src_set, tile_id, dest_set) do
    GenServer.call(via_name(id), {:move_tile, src_set, tile_id, dest_set})
  end

  def can_end_turn?(id) do
    GenServer.call(via_name(id), :can_end_turn)
  end

  def end_turn(id) do
    GenServer.call(via_name(id), :end_turn)
  end

  def get_session(id) do
    GenServer.call(via_name(id), :get_session)
  end

  def active?(id) do
    Registry.lookup(Rummy.Server.Registry, id) != []
  end

  def start_link(options) do
    server_id = Keyword.get(options, :server_id)

    GenServer.start_link(__MODULE__, Session.new(server_id), options)
  end

  @impl true
  def init(session) do
    {:ok, session}
  end

  @impl true
  def handle_call({:add_player, player_name}, _from, session) do
    session
    |> Session.add_player(player_name)
    |> broadcast(session.id, {:session_updated, :player_joined})
    |> case do
      {:ok, {player, session}} -> {:reply, {:ok, player}, session}
      {:error, _reason} = err -> {:reply, err, session}
    end
  end

  @impl true
  def handle_call({:remove_player, player_id}, _from, session) do
    session
    |> Session.remove_player(player_id)
    |> broadcast(session.id, {:session_updated, :player_left})
    |> case do
      {:ok, session} ->
        case session.players do
          [] ->
            {:stop, :normal, {:ok, session}, session}

          _ ->
            {:reply, {:ok, session}, session}
        end

      {:error, _reason} = err ->
        {:reply, err, session}
    end
  end

  @impl true
  def handle_call(:pick_tile, _from, session) do
    session
    |> Rummy.Game.Session.pick_tile()
    |> broadcast(session.id, {:session_updated, :tile_picked})
    |> call_reply(session)
  end

  @impl true
  def handle_call({:move_tile, src_set, tile_id, dest_set}, _from, session) do
    session
    |> Rummy.Game.Session.move_tile(src_set, tile_id, dest_set)
    |> broadcast(session.id, {:session_updated, :tile_moved})
    |> call_reply(session)
  end

  @impl true
  def handle_call(:can_end_turn, _from, session) do
    {:reply, Session.can_end_turn?(session), session}
  end

  @impl true
  def handle_call(:end_turn, _from, session) do
    session
    |> Rummy.Game.Session.end_turn()
    |> broadcast(session.id, {:session_updated, :turn_ended})
    |> call_reply(session)
  end

  @impl true
  def handle_call(:get_session, _from, session) do
    {:reply, session, session}
  end

  defp via_name(id) do
    {:via, Registry, {Rummy.Server.Registry, id}}
  end

  defp generate_server_id() do
    ?a..?z |> Enum.take_random(6) |> List.to_string()
  end

  defp call_reply({:error, _} = result, state), do: {:reply, result, state}
  defp call_reply({:ok, %Session{} = session} = result, _state), do: {:reply, result, session}

  defp broadcast({:error, _} = result, _id, _msg), do: result

  defp broadcast({:ok, _} = result, id, msg) do
    PubSub.broadcast(Rummy.PubSub, topic(id), msg)
    result
  end

  defp topic(game_id), do: "game:#{game_id}"
end
