defmodule Rummy.Game.Player do
  defstruct [:id, :name, :rack, :played_initial_30?]

  def new(id, name, rack) when is_integer(id) and is_list(rack) do
    %__MODULE__{id: id, name: name, rack: rack, played_initial_30?: false}
  end

  def take_tile(%{rack: rack} = player, tile_id) do
    with {:ok, {tile, rest}} <- Rummy.Game.Set.take_tile(rack, tile_id) do
      {:ok, {tile, %{player | rack: rest}}}
    end
  end

  def add_tile(player, %Rummy.Game.Tile{} = tile) do
    Map.update!(player, :rack, &[tile | &1])
  end
end