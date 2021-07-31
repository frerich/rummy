defmodule Rummy do
  @moduledoc """
  Rummy keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  alias Rummy.Game.{Player, Session}

  def new_session() do
    Session.new()
  end

  def add_player_to_session(session, player_name) do
    Session.add_player(session, player_name)
  end

  def pick_tile(session) do
    with {:ok, {tile, session}} <- Session.pick_tile_from_pool(session),
         {:ok, session} <- Session.update_current_player(session, &Player.add_tile(&1, tile)),
         {:ok, session} <- Session.end_turn(session) do
      session
    end
  end

  def end_turn(session) do
    Session.end_turn(session)
  end

  def make_new_set(session, tile_index) do
    with {:ok, {tile, session}} <- take_tile_from_current_player(session, tile_index) do
      Session.make_new_set(session, tile)
    end
  end

  def amend_set(session, set_index, tile_index) do
    with {:ok, {tile, session}} <- take_tile_from_current_player(session, tile_index) do
      Session.amend_set(session, set_index, tile)
    end
  end

  defp take_tile_from_current_player(session, tile_index) do
    with {:ok, player} <- Session.current_player(session),
         {:ok, {tile, player}} <- Player.take_tile_at(player, tile_index),
         {:ok, session} <- Session.update_current_player(session, fn _ -> player end) do
      {:ok, {tile, session}}
    end
  end
end
