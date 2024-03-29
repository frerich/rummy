defmodule Rummy.Game.Session do
  @moduledoc false

  alias Rummy.Game.{Player, Set, Tile}

  defstruct id: nil,
            players: [],
            pool: [],
            sets: [],
            state: :round_start,
            tiles_played_in_round: [],
            round_time: 0

  @initial_number_of_tiles 14

  def new(id) do
    %__MODULE__{
      id: id,
      pool: Enum.shuffle(Tile.pool())
    }
  end

  def add_player(session, _player_name) when length(session.pool) < @initial_number_of_tiles do
    {:error, :not_enough_tiles}
  end

  def add_player(session, player_name) do
    {rack, pool} = Enum.split(session.pool, @initial_number_of_tiles)

    player_id = Enum.random(1..10_000_000)
    player = Player.new(player_id, player_name, rack)

    session = %{session | pool: pool, players: session.players ++ [player]}

    {:ok, {player, session}}
  end

  def remove_player(session, player_id) do
    case Enum.split_with(session.players, &(&1.id == player_id)) do
      {[player], others} ->
        session = %{session | players: others, pool: player.rack ++ session.pool}

        {:ok, session}

      _ ->
        {:error, :invalid_player_id}
    end
  end

  def pick_tile(%{state: state}) when state != :round_start,
    do: {:error, :can_only_pick_at_start_of_round}

  def pick_tile(%{pool: []}),
    do: {:error, :not_enough_tiles}

  def pick_tile(%{players: []}),
    do: {:error, :not_enough_players}

  def pick_tile(%{pool: [tile | pool]} = session) do
    with {:ok, %{players: [current | next]} = session} <- put_tile(session, tile, :rack) do
      {:ok, %{session | players: next ++ [current], pool: pool}}
    end
  end

  def end_turn(%{players: [current | next]} = session) do
    played_initial_30? = current.played_initial_30? || played_set_worth_30_or_more(session)
    current = %{current | played_initial_30?: played_initial_30?}

    case current.rack do
      [] ->
        {:ok, %{session | state: :game_finished}}

      _ ->
        {:ok,
         %{session | state: :round_start, players: next ++ [current], tiles_played_in_round: []}}
    end
  end

  def can_end_turn?(%{players: []}), do: {:error, :not_enough_players}

  def can_end_turn?(%{players: [%{played_initial_30?: true} | _]} = session) do
    Enum.all?(session.sets, &Set.valid?/1)
  end

  def can_end_turn?(%{players: [%{played_initial_30?: false} | _]} = session) do
    all_sets_valid = Enum.all?(session.sets, &Set.valid?/1)

    all_sets_valid and played_set_worth_30_or_more(session)
  end

  def current_player(%{players: []}), do: {:error, :not_enough_players}
  def current_player(%{players: [p | _]}), do: {:ok, p}

  def move_tile(session, src_set, _tile_id, dest_set) when src_set == dest_set do
    {:ok, session}
  end

  def move_tile(session, src_set, tile_id, dest_set) do
    %{
      tiles_played_in_round: tiles_played
    } = session

    if is_integer(src_set) and dest_set == :rack and tile_id not in tiles_played do
      {:error, :tile_not_played_in_round}
    else
      with {:ok, {tile, session}} <- take_tile(session, tile_id, src_set),
           {:ok, session} <- put_tile(session, tile, dest_set) do
        session =
          session
          |> update_state_after_tile_move(src_set, tile_id, dest_set)
          |> purge_empty_sets()

        {:ok, session}
      end
    end
  end

  defp update_state_after_tile_move(
         %{tiles_played_in_round: tiles_played} = session,
         :rack,
         tile_id,
         :new_set
       ) do
    %{session | tiles_played_in_round: [tile_id | tiles_played], state: :tile_moved}
  end

  defp update_state_after_tile_move(
         %{tiles_played_in_round: tiles_played} = session,
         :rack,
         tile_id,
         dest_set
       )
       when is_integer(dest_set) do
    %{session | tiles_played_in_round: [tile_id | tiles_played], state: :tile_moved}
  end

  defp update_state_after_tile_move(
         %{tiles_played_in_round: tiles_played} = session,
         src_set,
         tile_id,
         :rack
       )
       when is_integer(src_set) do
    case List.delete(tiles_played, tile_id) do
      [] -> %{session | tiles_played_in_round: [], state: :round_start}
      tiles -> %{session | tiles_played_in_round: tiles, state: :tile_moved}
    end
  end

  defp update_state_after_tile_move(session, _set_set, _tile_id, _dest_set) do
    %{session | state: :tile_moved}
  end

  def reset_round_time(session) do
    %{session | round_time: 0}
  end

  def update_round_time(%{players: []}, _increment), do: {:error, :not_enough_players}

  def update_round_time(%{round_time: round_time} = session, increment) do
    {:ok, %{session | round_time: round_time + increment}}
  end

  defp take_tile(%{players: []}, _tile_id, :rack),
    do: {:error, :not_enough_players}

  defp take_tile(%{players: [current | players]} = session, tile_id, :rack) do
    with {:ok, {tile, player}} <- Player.take_tile(current, tile_id) do
      {:ok, {tile, %{session | players: [player | players]}}}
    end
  end

  defp take_tile(%{sets: sets}, _tile_id, set_index) when set_index not in 0..(length(sets) - 1),
    do: {:error, :invalid_index}

  defp take_tile(%{sets: sets} = session, tile_id, set_index) when is_integer(set_index) do
    with {:ok, {tile, new_set}} <- Set.take_tile(Enum.at(sets, set_index), tile_id) do
      session = %{session | sets: List.update_at(sets, set_index, fn _ -> new_set end)}
      {:ok, {tile, session}}
    end
  end

  defp put_tile(%{sets: sets} = session, tile, :new_set),
    do: {:ok, %{session | sets: [[tile] | sets]}}

  defp put_tile(%{players: []}, _tile, :rack),
    do: {:error, :not_enough_players}

  defp put_tile(%{players: players} = session, tile, :rack),
    do: {:ok, %{session | players: List.update_at(players, 0, &Player.add_tile(&1, tile))}}

  defp put_tile(%{sets: sets}, _tile, index) when index not in 0..(length(sets) - 1),
    do: {:error, :invalid_index}

  defp put_tile(%{sets: sets} = session, tile, index),
    do: {:ok, %{session | sets: List.update_at(sets, index, &Set.add_tile(&1, tile))}}

  defp purge_empty_sets(session),
    do: %{session | sets: Enum.reject(session.sets, &(&1 == []))}

  defp played_set_worth_30_or_more(session) do
    newly_played_sets =
      session.sets
      |> Enum.filter(fn set -> Enum.all?(set, &(&1.id in session.tiles_played_in_round)) end)

    Enum.any?(newly_played_sets, &(Set.value(&1) >= 30))
  end
end
