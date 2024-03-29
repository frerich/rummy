defmodule RummyWeb.MainLive do
  @moduledoc false

  use RummyWeb, :live_view

  alias Rummy.Game.Session
  alias Rummy.Server

  @version Mix.Project.config()[:version]

  @impl true
  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(version: @version)
      |> assign(flash_message: nil)
      |> assign(game_id: Map.get(params, "game_id"))
      |> assign(player_id: nil)
      |> assign_game_state()

    {:ok, socket}
  end

  @impl true
  def handle_event("start", %{"name" => name}, socket) do
    {:ok, game_id} = Server.start()

    socket =
      socket
      |> enter_game(game_id, name)
      |> push_patch(to: Routes.main_path(socket, :index, game_id))

    {:noreply, socket}
  end

  @impl true
  def handle_event("join", %{"name" => name}, socket) do
    {:noreply, enter_game(socket, socket.assigns.game_id, name)}
  end

  @impl true
  def handle_event("tile-moved", params, socket) do
    %{
      "destSet" => dest_set,
      "srcSet" => src_set,
      "tileId" => tile_id
    } = params

    Server.move_tile(
      socket.assigns.game_id,
      parse_set_id(src_set),
      String.to_integer(tile_id),
      parse_set_id(dest_set)
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("pick-tile", _params, socket) do
    Server.pick_tile(socket.assigns.game_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("end-turn", _params, socket) do
    Server.end_turn(socket.assigns.game_id)
    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    # Need this because we use push_patch.
    {:noreply, assign(socket, invite_uri: uri)}
  end

  @impl true
  def handle_info({:session_updated, _what}, socket) do
    {:noreply, assign_session(socket, Server.get_session(socket.assigns.game_id))}
  end

  defp assign_session(socket, session) do
    {:ok, current_player} = Session.current_player(session)

    local_player = Enum.find(session.players, &(&1.id == socket.assigns.player_id))

    can_pick_tile? = local_player == current_player and session.pool != []
    can_end_turn? = local_player == current_player and Session.can_end_turn?(session)

    assign(socket,
      can_end_turn?: can_end_turn?,
      can_pick_tile?: can_pick_tile?,
      current_player: current_player,
      played_sets: session.sets,
      players: session.players,
      rack: local_player.rack,
      round_time: session.round_time,
      round_state: session.state
    )
  end

  defp enter_game(socket, game_id, player_name) do
    {:ok, player} = Server.add_player(game_id, player_name)

    socket
    |> assign(game_id: game_id)
    |> assign(player_id: player.id)
    |> assign_session(Server.get_session(game_id))
    |> assign_game_state()
  end

  defp assign_game_state(socket) do
    game_state =
      case socket.assigns do
        %{game_id: nil} -> :create_game
        %{player_id: nil} -> :join_game
        _ -> :play_game
      end

    case game_state do
      :create_game ->
        assign(socket, game_state: game_state)

      _ ->
        if Server.active?(socket.assigns.game_id) do
          assign(socket, game_state: game_state)
        else
          socket
          |> assign(
            flash_message: "Looks like you're late to the party! This game link is not valid. :-("
          )
          |> assign(game_state: :create_game)
        end
    end
  end

  defp css_classes_for_set(set) do
    if Rummy.Game.Set.valid?(set) do
      "set"
    else
      "invalid set"
    end
  end

  defp sorted_set(set) do
    Rummy.Game.Set.sort(set)
  end

  defp parse_set_id("new_set"), do: :new_set
  defp parse_set_id("rack"), do: :rack
  defp parse_set_id(index), do: String.to_integer(index)
end
