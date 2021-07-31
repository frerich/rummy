defmodule Rummy.Game.Tile do
  @colors ~w(blue red orange black)a
  @values 1..13

  defstruct [:color, :value]

  def new(color, value) when color in @colors and value in @values do
    %__MODULE__{color: color, value: value}
  end

  def pool() do
    set = for color <- @colors, value <- @values, do: new(color, value)
    set ++ set
  end
end
