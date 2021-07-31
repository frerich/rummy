defmodule Rummy.Game.Session do
  alias Rummy.Game.{Player, Set}

  defstruct players: [], pool: [], sets: []

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

    player = Player.new(player_name, rack)

    session
    |> Map.put(:pool, pool)
    |> Map.update!(:players, &[player | &1])
  end

  def pick_tile_from_pool(%{pool: []}), do: {:error, :not_enough_tiles}

  def pick_tile_from_pool(%{pool: [tile | pool]} = session) do
    {:ok, {tile, %{session | pool: pool}}}
  end

  def end_turn(%{players: []}), do: {:error, :not_enough_players}

  def end_turn(%{players: [current | next], sets: sets} = session) do
    if Enum.all?(sets, &Set.valid?/1) do
      {:ok, Map.put(session, :players, next ++ [current])}
    else
      {:error, :invalid_sets}
    end
  end

  def make_new_set(%{sets: sets} = session, tile) do
    %{session | sets: [[tile] | sets]}
  end

  def amend_set(%{sets: sets}, index, _tile) when index not in 0..length(sets) - 1, do: {:error, :invalid_index}
  def amend_set(%{sets: sets} = session, index, tile) do
    %{session | sets: List.update_at(sets, index, & [tile | &1])}
  end

  def current_player(%{players: []}), do: {:error, :not_enough_players}
  def current_player(%{players: [current | _rest]}), do: {:ok, current}

  def update_current_player(%{players: []}, _fun), do: {:error, :not_enough_players}

  def update_current_player(%{players: [current | rest]} = session, fun) do
    {:ok, Map.put(session, :players, [fun.(current) | rest])}
  end
end
