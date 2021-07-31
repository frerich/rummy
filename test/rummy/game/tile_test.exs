defmodule Rummy.TileTest do
  use ExUnit.Case, async: true

  alias Rummy.Game.Tile

  describe("Tile.new/1") do
    test "creating valid number tiles" do
      numbers = 1..13
      colors = ~w(red blue orange black)a

      for number <- numbers, color <- colors do
        tile = Tile.new(:dummy_id, color, number)
        assert tile.color == color
        assert tile.value == number
      end
    end

    test "creating valid joker tiles" do
      for color <- [:orange, :black] do
        tile = Tile.new(:dummy_id, color, :joker)
        assert tile.color == color
        assert tile.value == :joker
      end
    end

    test "creating number tiles with invalid numbers" do
      for value <- [-1, 0, 14], color <- ~w(red blue orange black) do
        assert_raise FunctionClauseError, fn ->
          Tile.new(:dummy_id, value, color)
        end
      end
    end

    test "creating number tiles with invalid colors" do
      for value <- 1..13, color <- ~w(pink cyan yellow brown)a do
        assert_raise FunctionClauseError, fn ->
          Tile.new(:dummy_id, value, color)
        end
      end
    end
  end

  describe "Tile.pool/0" do
    test "pool size" do
      assert length(Tile.pool()) == 106
    end

    test "there are two jokers" do
      assert Enum.count(Tile.pool(), &(&1.value == :joker)) == 2
    end

    test "every number tile is present twice" do
      Tile.pool()
      |> Enum.reject(&(&1.value == :joker))
      |> Enum.frequencies_by(&{&1.color, &1.value})
      |> Map.values()
      |> Enum.all?(&(&1 == 2))
      |> assert
    end

    test "all tile IDs are unique" do
      num_tiles = Tile.pool() |> length
      num_unique_ids = Tile.pool() |> Enum.uniq_by(& &1.id) |> length
      assert num_tiles == num_unique_ids
    end
  end
end
