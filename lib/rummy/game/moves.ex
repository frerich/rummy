defmodule Rummy.Game.Moves do
  alias Rummy.Game.Session

  def pick_tile(%{state: :round_start} = session) do
    with {:ok, {tile, session}} <- Session.pick_tile_from_pool(session),
         {:ok, session} <- Session.amend_rack(session, tile),
         {:ok, session} <- Session.end_turn(session) do
      {:ok, session}
    end
  end

  def recall_tile(session, set_index, tile_index) do
    with {:ok, {tile, session}} <- Session.pick_tile_from_set(session, set_index, tile_index),
         {:ok, session} <- Session.amend_rack(session, tile),
         {:ok, session} <- Session.forget_tile_played(session, tile),
         session <- purge_empty_sets(session) do
      new_state =
        case session.tiles_played_in_round do
          [] -> :round_start
          _ -> :tile_moved
        end

      {:ok, %{session | state: new_state}}
    end
  end

  def create_set(session, :rack, tile_index) do
    with {:ok, {tile, session}} <- Session.pick_tile_from_current_player(session, tile_index),
         {:ok, session} <- Session.create_set(session, tile),
         {:ok, session} <- Session.remember_tile_played(session, tile) do
      {:ok, %{session | state: :tile_moved}}
    end
  end

  def create_set(session, set_index, tile_index) do
    with {:ok, {tile, session}} <- Session.pick_tile_from_set(session, set_index, tile_index),
         {:ok, session} <- Session.create_set(session, tile),
         session <- purge_empty_sets(session) do
      {:ok, %{session | state: :tile_moved}}
    end
  end

  def amend_set(session, dst_set_index, :rack, tile_index) do
    with {:ok, {tile, session}} <- Session.pick_tile_from_current_player(session, tile_index),
         {:ok, session} <- Session.amend_set(session, dst_set_index, tile),
         {:ok, session} <- Session.remember_tile_played(session, tile) do
      {:ok, %{session | state: :tile_moved}}
    end
  end

  def amend_set(session, dst_set_index, src_set_index, tile_index) do
    with {:ok, {tile, session}} <- Session.pick_tile_from_set(session, src_set_index, tile_index),
         {:ok, session} <- Session.amend_set(session, dst_set_index, tile),
         session <- purge_empty_sets(session) do
      {:ok, %{session | state: :tile_moved}}
    end
  end

  def end_turn(session) do
    with true <- Session.can_end_turn?(session),
         {:ok, current_player} <- Session.current_player(session) do
      case current_player.rack do
        [] ->
          {:ok, %{session | state: :game_finished}}

        _ ->
          with {:ok, session} <- Session.end_turn(session) do
            {:ok, %{session | state: :round_start}}
          end
      end
    end
  end

  defp purge_empty_sets(session) do
    %{session | sets: Enum.reject(session.sets, &(&1 == []))}
  end
end
