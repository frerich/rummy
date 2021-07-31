defmodule Rummy do
  @moduledoc """
  Rummy keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  alias Rummy.Server
  alias Phoenix.PubSub

  def start_game() do
    Server.start()
  end

  def game_running?(id) do
    Server.active?(id)
  end

  def get_session(id) do
    Server.get_session(id)
  end

  def join_game(id, player_name) do
    with {:ok, player} <- Server.add_player(id, player_name),
         :ok <- Rummy.ProcessMonitor.watch(self(), fn _reason -> Rummy.leave_game(id, player.id) end),
         :ok <- PubSub.broadcast(Rummy.PubSub, topic(id), {:session_updated, :player_joined}),
         :ok <- PubSub.subscribe(Rummy.PubSub, topic(id)) do
      {:ok, player}
    end
  end

  def leave_game(id, player_id) do
    Server.remove_player(id, player_id)
    |> broadcast(id, {:session_updated, :player_left})
  end

  def pick_tile(id) do
    Server.pick_tile(id)
    |> broadcast(id, {:session_updated, :tile_picked})
  end

  def recall_tile(id, set_index, tile_index) do
    Server.recall_tile(id, set_index, tile_index)
    |> broadcast(id, {:session_updated, :tile_recalled})
  end

  def create_set(id, set_index, tile_index) do
    Server.create_set(id, set_index, tile_index)
    |> broadcast(id, {:session_updated, :set_created})
  end

  def amend_set(id, dst_set_index, src_set_index, tile_index) do
    Server.amend_set(id, dst_set_index, src_set_index, tile_index)
    |> broadcast(id, {:session_updated, :set_amended})
  end

  def can_end_turn?(id) do
    Server.can_end_turn?(id)
  end

  def end_turn(id) do
    Server.end_turn(id)
    |> broadcast(id, {:session_updated, :turn_ended})
  end

  defp topic(game_id), do: "game:#{game_id}"

  defp broadcast(input, id, message) do
    PubSub.broadcast(Rummy.PubSub, topic(id), message)
    input
  end
end
