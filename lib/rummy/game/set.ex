defmodule Rummy.Game.Set do
  def run?(tiles) do
    numbered = only_numbered(tiles)

    colors = Enum.map(numbered, & &1.color)
    values = Enum.map(numbered, & &1.value)

    Enum.count(tiles) >= 3 and all_equal?(colors) and all_distinct?(values) and ascending?(tiles)
  end

  def group?(tiles) do
    numbered = only_numbered(tiles)

    colors = Enum.map(numbered, & &1.color)
    values = Enum.map(numbered, & &1.value)

    Enum.count(tiles) in [3, 4] and all_distinct?(colors) and all_equal?(values)
  end

  def valid?(tiles), do: run?(tiles) or group?(tiles)

  def value(tiles) do
    cond do
      run?(tiles) ->
        {numbered_tile, index} =
          tiles
          |> sort()
          |> Enum.with_index()
          |> Enum.find(fn {tile, _index} -> tile.value != :joker end)

        first_value = numbered_tile.value - index
        Enum.sum(first_value..first_value + Enum.count(tiles) - 1)

      group?(tiles) ->
        numbered_tile = Enum.find(tiles, & &1.value != :joker)
        numbered_tile.value * Enum.count(tiles)

      true ->
        true = valid?(tiles)
    end
  end

  def sort(tiles) do
    cond do
      run?(tiles) ->
        {jokers, numbered} = Enum.split_with(tiles, &(&1.value == :joker))

        jokers = Enum.sort_by(jokers, & &1.color)
        [highest_valued | rest] = Enum.sort_by(numbered, & &1.value, :desc)

        # First, fill all gaps
        {tiles_without_gaps, jokers_remaining} =
          Enum.reduce(rest, {[highest_valued], jokers}, fn
            tile, {[last | _] = tiles, jokers} ->
              gap_length = last.value - tile.value - 1
              {jokers_for_gap, jokers_left} = Enum.split(jokers, gap_length)
              {[tile] ++ jokers_for_gap ++ tiles, jokers_left}
          end)

        # Next, try to use remaining jokers at the top (highest value)
        {jokers_for_top, jokers_remaining} = Enum.split(jokers_remaining, 13 - highest_valued.value)
        tiles_without_gaps = tiles_without_gaps ++ jokers_for_top

        # Use remaininig jokers at the bottom
        jokers_remaining ++ tiles_without_gaps

      group?(tiles) ->
        Enum.sort_by(tiles, & [&1.color, &1.value])
      true ->
        Enum.sort_by(tiles, & [&1.color, &1.value])
    end
  end

  def take_tile_at(_tiles, index) when not is_integer(index) or index < 0,
    do: {:error, :invalid_index}

  def take_tile_at(tiles, index) do
    case List.pop_at(tiles, index) do
      {nil, _} -> {:error, :not_enough_tiles}
      {tile, rest} -> {:ok, {tile, rest}}
    end
  end

  defp all_equal?([]), do: true
  defp all_equal?([x | xs]), do: Enum.all?(xs, &(&1 == x))

  defp all_distinct?(xs) do
    Enum.count(xs) == Enum.count(Enum.uniq(xs))
  end

  defp ascending?(xs) do
    case Enum.split_with(xs, &(&1.value == :joker)) do
      {_jokers, [] = _numbered} ->
        true

      {jokers, numbered} ->
        numbered = Enum.sort(numbered)

        num_jokers_required =
          numbered
          |> Enum.zip_with(tl(numbered), fn x, y -> y.value - x.value - 1 end)
          |> Enum.sum()

        num_jokers_required <= length(jokers)
    end
  end

  defp only_numbered(xs) do
    Enum.reject(xs, &(&1.value == :joker))
  end
end
