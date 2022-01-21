defmodule Rummy.Game.Tile do
  @moduledoc false

  @colors ~w(blue red orange black)a
  @values 1..13

  defstruct [:id, :color, :value]

  def new(id, color, value) when color in @colors and (value in @values or value == :joker) do
    %__MODULE__{id: id, color: color, value: value}
  end

  def pool do
    numbered = for color <- @colors, value <- @values, do: {color, value}

    jokers = [{:black, :joker}, {:orange, :joker}]

    (numbered ++ numbered ++ jokers)
    |> Enum.with_index(fn {color, value}, index -> new(index, color, value) end)
  end
end
