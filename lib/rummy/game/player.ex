defmodule Rummy.Game.Player do
  defstruct [:name, :rack]

  def new(name, rack) when is_list(rack) do
    %__MODULE__{name: name, rack: rack}
  end

  def take_tile_at(_player, index) when not is_integer(index) or index < 0, do: {:error, :invalid_index}
  def take_tile_at(%{rack: rack} = player, index) do
    case List.pop_at(rack, index) do
      {nil, _} -> {:error, :not_enough_tiles}
      {tile, rest} -> {:ok, {tile, %{player | rack: rest}}}
    end
  end

  def add_tile(player, %Rummy.Game.Tile{} = tile) do
    Map.update!(player, :rack, &[tile | &1])
  end
end
