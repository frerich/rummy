defmodule Rummy.Game.Set do
  def run?(tiles) do
    colors = Enum.map(tiles, & &1.color)
    values = Enum.map(tiles, & &1.value)

    Enum.count(tiles) >= 3 and all_equal?(colors) and ascending?(values)
  end

  def group?(tiles) do
    colors = Enum.map(tiles, & &1.color)
    values = Enum.map(tiles, & &1.value)

    Enum.count(tiles) in [3, 4] and all_distinct?(colors) and all_equal?(values)
  end

  def valid?(tiles), do: run?(tiles) or group?(tiles)

  def value(tiles) do
    tiles
    |> Enum.map(& &1.value)
    |> Enum.sum()
  end

  defp all_equal?([]), do: true
  defp all_equal?([x | xs]), do: Enum.all?(xs, &(&1 == x))

  defp all_distinct?(xs) do
    Enum.count(xs) == Enum.count(Enum.uniq(xs))
  end

  defp ascending?([]), do: true

  defp ascending?(xs) do
    sorted = Enum.sort(xs)

    sorted
    |> Enum.zip(tl(sorted))
    |> Enum.all?(fn {x, y} -> x + 1 == y end)
  end
end
