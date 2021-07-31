defmodule Rummy.Server do
  use GenServer, restart: :transient

  alias Rummy.Game.Session

  def start() do
    id = generate_server_id()

    case DynamicSupervisor.start_child(
           Rummy.Server.Supervisor,
           {Rummy.Server, name: via_name(id)}
         ) do
      {:ok, _pid} ->
        {:ok, id}

      other ->
        other
    end
  end

  def add_player(id, player_name) do
    GenServer.call(via_name(id), {:add_player, player_name})
  end

  def remove_player(id, player_id) do
    GenServer.call(via_name(id), {:remove_player, player_id})
  end

  def pick_tile(id) do
    GenServer.call(via_name(id), :pick_tile)
  end

  def recall_tile(id, set_index, tile_index) do
    GenServer.call(via_name(id), {:recall_tile, set_index, tile_index})
  end

  def create_set(id, set_index, tile_index) do
    GenServer.call(via_name(id), {:create_set, set_index, tile_index})
  end

  def amend_set(id, dst_set_index, src_set_index, tile_index) do
    GenServer.call(via_name(id), {:amend_set, dst_set_index, src_set_index, tile_index})
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
    GenServer.start_link(__MODULE__, Session.new(), options)
  end

  @impl true
  def init(session) do
    {:ok, session}
  end

  @impl true
  def handle_call({:add_player, player_name}, _from, session) do
    case Session.add_player(session, player_name) do
      {:ok, {player, session}} -> {:reply, {:ok, player}, session}
      {:error, _reason} = err -> {:reply, err, session}
    end
  end

  @impl true
  def handle_call({:remove_player, player_id}, _from, session) do
    case Session.remove_player(session, player_id) do
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
    |> Rummy.Game.Moves.pick_tile()
    |> call_reply(session)
  end

  @impl true
  def handle_call({:recall_tile, set_index, tile_index}, _from, session) do
    session
    |> Rummy.Game.Moves.recall_tile(set_index, tile_index)
    |> call_reply(session)
  end

  @impl true
  def handle_call({:create_set, set_index, tile_index}, _from, session) do
    session
    |> Rummy.Game.Moves.create_set(set_index, tile_index)
    |> call_reply(session)
  end

  @impl true
  def handle_call({:amend_set, dst_set_index, src_set_index, tile_index}, _from, session) do
    session
    |> Rummy.Game.Moves.amend_set(dst_set_index, src_set_index, tile_index)
    |> call_reply(session)
  end

  @impl true
  def handle_call(:can_end_turn, _from, session) do
    {:reply, Session.can_end_turn?(session), session}
  end

  @impl true
  def handle_call(:end_turn, _from, session) do
    session
    |> Rummy.Game.Moves.end_turn()
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
end
