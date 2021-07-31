defmodule Rummy.Game.Session do
  alias Rummy.Game.{Player, Set}

  defstruct players: [], pool: [], sets: [], state: :round_start, tiles_played_in_round: []

  @initial_number_of_tiles 14

  def new() do
    %__MODULE__{
      pool: Enum.shuffle(Rummy.Game.Tile.pool())
    }
  end

  def add_player(session, _player_name) when length(session.pool) < @initial_number_of_tiles do
    {:error, :not_enough_tiles}
  end

  def add_player(session, player_name) do
    {rack, pool} = Enum.split(session.pool, @initial_number_of_tiles)

    player_id = Enum.random(1..1_0000_000)
    player = Player.new(player_id, player_name, rack)

    session =
      session
      |> Map.put(:pool, pool)
      |> Map.update!(:players, &(&1 ++ [player]))

    {:ok, {player, session}}
  end

  def remove_player(session, player_id) do
    case Enum.split_with(session.players, &(&1.id == player_id)) do
      {[player], others} ->
        session =
          session
          |> Map.update!(:pool, &(player.rack ++ &1))
          |> Map.put(:players, others)

        {:ok, session}

      _ ->
        {:error, :invalid_player_id}
    end
  end

  def pick_tile_from_pool(%{pool: []}), do: {:error, :not_enough_tiles}

  def pick_tile_from_pool(%{pool: [tile | pool]} = session) do
    {:ok, {tile, %{session | pool: pool}}}
  end

  def pick_tile_from_set(%{sets: sets}, set_index, _tile_index)
      when set_index not in 0..(length(sets) - 1),
      do: {:error, :invalid_set_index}

  def pick_tile_from_set(%{sets: sets} = session, set_index, tile_index) do
    set = Enum.at(sets, set_index)

    with {:ok, {tile, rest}} <- Set.take_tile_at(set, tile_index) do
      session = %{session | sets: List.update_at(sets, set_index, fn _ -> rest end)}
      {:ok, {tile, session}}
    end
  end

  def pick_tile_from_current_player(%{players: []}, _tile_index),
    do: {:error, :not_enough_players}

  def pick_tile_from_current_player(%{players: [current | next]} = session, tile_index) do
    with {:ok, {tile, player}} <- Player.take_tile_at(current, tile_index) do
      session = %{session | players: [player | next]}
      {:ok, {tile, session}}
    end
  end

  def end_turn(%{players: [current | next]} = session) do
    {:ok, %{session | players: next ++ [current], tiles_played_in_round: []}}
  end

  def can_end_turn?(%{players: []}), do: {:error, :not_enough_players}

  def can_end_turn?(%{players: [%{played_initial_30?: true} | _]} = session) do
    Enum.all?(session.sets, &Set.valid?/1)
  end

  def can_end_turn?(%{players: [%{played_initial_30?: false} | _]} = session) do
    all_sets_valid = Enum.all?(session.sets, &Set.valid?/1)

    played_set_worth_30_or_more =
      session.sets
      |> Enum.filter(fn set -> Enum.all?(set, &(&1.id in session.tiles_played_in_round)) end)
      |> Enum.any?(&(Set.value(&1) >= 30))

    all_sets_valid and played_set_worth_30_or_more
  end

  def create_set(%{sets: sets} = session, tile) do
    {:ok, %{session | sets: [[tile] | sets]}}
  end

  def amend_set(%{sets: sets}, index, _tile) when index not in 0..(length(sets) - 1),
    do: {:error, :invalid_index}

  def amend_set(%{sets: sets} = session, index, tile) do
    {:ok, %{session | sets: List.update_at(sets, index, &[tile | &1])}}
  end

  def amend_rack(%{players: []}, _tile), do: {:error, :not_enough_players}

  def amend_rack(%{players: [current | next]} = session, tile) do
    {:ok, %{session | players: [Player.add_tile(current, tile) | next]}}
  end

  def current_player(%{players: []}), do: {:error, :not_enough_players}
  def current_player(%{players: [p | _]}), do: {:ok, p}

  def remember_tile_played(%{tiles_played_in_round: tiles_played} = session, tile) do
    false = tile.id in tiles_played
    {:ok, %{session | tiles_played_in_round: [tile.id | tiles_played]}}
  end

  def forget_tile_played(session, tile) do
    case Enum.split_with(session.tiles_played_in_round, &(&1 == tile.id)) do
      {[_], rest} -> {:ok, %{session | tiles_played_in_round: rest}}
      {[], _rest} -> {:error, :tile_not_played_in_round}
    end
  end
end
