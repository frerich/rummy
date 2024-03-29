defmodule Rummy.Server do
  @moduledoc false

  use GenServer, restart: :transient

  alias Phoenix.PubSub
  alias Rummy.Game.Session

  def start do
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
    state = %{
      session: session,
      round_timer: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_info(:timer_tick, state) do
    case Session.update_round_time(state.session, 1) do
      {:ok, session} ->
        PubSub.broadcast(Rummy.PubSub, topic(session.id), {:session_updated, :round_time_updated})
        {:noreply, %{state | session: session}}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_call({:add_player, player_name}, _from, state) do
    state.session
    |> Session.add_player(player_name)
    |> broadcast(state.session.id, {:session_updated, :player_joined})
    |> case do
      {:ok, {player, session}} ->
        state = %{state | session: session}

        state =
          case session.players do
            [_] -> restart_round_timer(state)
            _ -> state
          end

        {:reply, {:ok, player}, state}

      {:error, _reason} = err ->
        {:reply, err, state}
    end
  end

  @impl true
  def handle_call({:remove_player, player_id}, _from, state) do
    state.session
    |> Session.remove_player(player_id)
    |> broadcast(state.session.id, {:session_updated, :player_left})
    |> case do
      {:ok, session} ->
        state = %{state | session: session}

        case session.players do
          [] ->
            {:stop, :normal, {:ok, session}, state}

          _ ->
            # XXX Update round timer!
            {:reply, {:ok, session}, state}
        end

      {:error, _reason} = err ->
        {:reply, err, state}
    end
  end

  @impl true
  def handle_call(:pick_tile, _from, state) do
    state.session
    |> Session.pick_tile()
    |> broadcast(state.session.id, {:session_updated, :tile_picked})
    |> case do
      {:ok, session} = result ->
        state = restart_round_timer(%{state | session: session})

        {:reply, result, state}

      result ->
        {:reply, result, state}
    end
  end

  @impl true
  def handle_call({:move_tile, src_set, tile_id, dest_set}, _from, state) do
    state.session
    |> Session.move_tile(src_set, tile_id, dest_set)
    |> broadcast(state.session.id, {:session_updated, :tile_moved})
    |> call_reply(state)
  end

  @impl true
  def handle_call(:can_end_turn, _from, state) do
    {:reply, Session.can_end_turn?(state.session), state}
  end

  @impl true
  def handle_call(:end_turn, _from, state) do
    state.session
    |> Session.end_turn()
    |> broadcast(state.session.id, {:session_updated, :turn_ended})
    |> case do
      {:ok, session} = result ->
        state = restart_round_timer(%{state | session: session})

        {:reply, result, state}

      result ->
        {:reply, result, state}
    end
  end

  @impl true
  def handle_call(:get_session, _from, state) do
    {:reply, state.session, state}
  end

  defp via_name(id) do
    {:via, Registry, {Rummy.Server.Registry, id}}
  end

  defp generate_server_id do
    ?a..?z |> Enum.take_random(6) |> List.to_string()
  end

  defp call_reply({:error, _} = result, state), do: {:reply, result, state}

  defp call_reply({:ok, %Session{} = session} = result, state),
    do: {:reply, result, %{state | session: session}}

  defp broadcast({:error, _} = result, _id, _msg), do: result

  defp broadcast({:ok, _} = result, id, msg) do
    PubSub.broadcast(Rummy.PubSub, topic(id), msg)
    result
  end

  defp topic(game_id), do: "game:#{game_id}"

  defp restart_round_timer(state) do
    if not is_nil(state.round_timer) do
      {:ok, _} = :timer.cancel(state.round_timer)
    end

    {:ok, timer} = :timer.send_interval(1000, :timer_tick)

    %{
      state
      | round_timer: timer,
        session: Session.reset_round_time(state.session)
    }
  end
end
