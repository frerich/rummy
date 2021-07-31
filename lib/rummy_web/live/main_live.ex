defmodule RummyWeb.MainLive do
  use RummyWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(flash_message: nil)
      |> assign(game_id: Map.get(params, "game_id"))
      |> assign(player_id: nil)
      |> assign_game_state()

    {:ok, socket}
  end

  @impl true
  def handle_event("start", %{"name" => name}, socket) do
    {:ok, game_id} = Rummy.start_game()

    socket =
      socket
      |> enter_game(game_id, name)
      |> push_patch(to: Routes.main_path(socket, :index, game_id))

    {:noreply, socket}
  end

  @impl true
  def handle_event("join", %{"name" => name}, socket) do
    socket =
      socket
      |> enter_game(socket.assigns.game_id, name)

    {:noreply, socket}
  end

  @impl true
  def handle_event("tile-moved", params, socket) do
    case params do
      %{"dst" => "new_set", "tileId" => tile_id} ->
        {set_index, tile_index} = tile_id_to_indices(socket.assigns.session, String.to_integer(tile_id))
        Rummy.create_set(socket.assigns.game_id, set_index, tile_index)

      %{"dst" => "rack", "tileId" => tile_id} ->
        case tile_id_to_indices(socket.assigns.session, String.to_integer(tile_id)) do
          {:rack, _tile_index} ->
            # We just ignore attempts to move a tile from the rack, to the rack.
            socket.assigns.session

          {set_index, tile_index} ->
            Rummy.recall_tile(socket.assigns.game_id, set_index, tile_index)
        end

      %{"dst" => dst_set_index, "tileId" => tile_id} ->
        {set_index, tile_index} = tile_id_to_indices(socket.assigns.session, String.to_integer(tile_id))
        Rummy.amend_set(socket.assigns.game_id, String.to_integer(dst_set_index), set_index, tile_index)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("pick-tile", _params, socket) do
    Rummy.pick_tile(socket.assigns.game_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("end-turn", _params, socket) do
    Rummy.end_turn(socket.assigns.game_id)
    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    # Need this because we use push_patch.
    {:noreply, assign(socket, invite_uri: uri)}
  end

  @impl true
  def handle_info({:session_updated, _what}, socket) do
    {:noreply, assign(socket, session: Rummy.get_session(socket.assigns.game_id))}
  end

  defp enter_game(socket, game_id, player_name) do
    {:ok, player} = Rummy.join_game(game_id, player_name)

    socket
    |> assign(game_id: game_id)
    |> assign(player_id: player.id)
    |> assign(session: Rummy.get_session(game_id))
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
        if Rummy.game_running?(socket.assigns.game_id) do
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

  defp player_by_id(session, player_id) do
    Enum.find(session.players, &(&1.id == player_id))
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

  defp current_player?(session, player_id) do
    {:ok, current_player} = Rummy.Game.Session.current_player(session)
    current_player.id == player_id
  end

  defp can_pick_tile?(session, player_id) do
    current_player?(session, player_id) and session.pool != []
  end

  defp can_end_turn?(session, player_id) do
    current_player?(session, player_id) and Rummy.Game.Session.can_end_turn?(session)
  end

  defp tile_id_to_indices(session, tile_id) do
    {:ok, current_player} = Rummy.Game.Session.current_player(session)

    sets = [{current_player.rack, :rack} | Enum.with_index(session.sets)]

    Enum.find_value(sets, fn {set, set_index} ->
      set
      |> Enum.with_index()
      |> Enum.find_value(fn {tile, tile_index} ->
        if tile.id == tile_id, do: {set_index, tile_index}
      end)
    end)
  end
end
