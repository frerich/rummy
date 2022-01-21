defmodule Rummy.SetTest do
  use ExUnit.Case, async: true

  alias Rummy.Game.{Set, Tile}

  describe "Set.run?/1" do
    test "a simple valid run" do
      assert Set.run?(tiles(black: 8, black: 9, black: 10))
    end

    test "all values need to be in order" do
      refute Set.run?(tiles(black: 7, black: 9, black: 10))
    end

    test "all colors need to be the same" do
      refute Set.run?(tiles(orange: 8, black: 9, blue: 10))
    end

    test "need at least three tiles for a valid run" do
      run = tiles(orange: 4, orange: 5, orange: 6, orange: 7)

      refute Set.run?(Enum.take(run, 0))
      refute Set.run?(Enum.take(run, 1))
      refute Set.run?(Enum.take(run, 2))
      assert Set.run?(Enum.take(run, 3))
      assert Set.run?(Enum.take(run, 4))
    end

    test "a joker can be used to complete a run at the front" do
      assert Set.run?(tiles(black: :joker, blue: 2, blue: 3))
    end

    test "a joker can be used to complete a run in the middle" do
      assert Set.run?(tiles(blue: 1, black: :joker, blue: 3))
    end

    test "a joker can be used to complete a run at the back" do
      assert Set.run?(tiles(blue: 1, blue: 2, black: :joker))
    end

    test "two jokes can be used to complete a run" do
      assert Set.run?(tiles(black: :joker, orange: :joker, blue: 3))
    end

    test "duplicate tile does not confuse the run detection" do
      refute Set.run?(tiles(red: 13, red: 13, red: 12, red: 10))
    end
  end

  describe "Set.group?/1" do
    test "a simple valid group" do
      assert Set.group?(tiles(blue: 7, red: 7, black: 7))
    end

    test "all values need to be equal" do
      refute Set.group?(tiles(blue: 8, red: 7, black: 7))
    end

    test "all colors need to be different" do
      refute Set.group?(tiles(black: 7, red: 7, black: 7))
    end

    test "a simple valid group needs three or four elements" do
      valid_group = tiles(blue: 7, red: 7, black: 7, orange: 7)

      refute Set.group?(Enum.take(valid_group, 0))
      refute Set.group?(Enum.take(valid_group, 1))
      refute Set.group?(Enum.take(valid_group, 2))
      assert Set.group?(Enum.take(valid_group, 3))
      assert Set.group?(Enum.take(valid_group, 4))
    end

    test "a joker can be used to complete a group" do
      assert Set.group?(tiles(blue: 7, black: :joker, black: 7))
    end

    test "two jokers can be used to complete a group" do
      assert Set.group?(tiles(blue: 7, black: :joker, orange: :joker))
    end
  end

  describe "Set.sort/1" do
    test "numbered tiles with same color are sorted by ascending value" do
      assert Set.sort(tiles(red: 10, red: 4, red: 11)) == tiles(red: 4, red: 10, red: 11)
    end

    test "colors are sorted lexicographically" do
      assert Set.sort(tiles(black: 7, red: 7, blue: 7)) == tiles(black: 7, blue: 7, red: 7)
    end

    test "sort by color first, then value" do
      assert Set.sort(tiles(red: 11, black: 7, blue: 8, blue: 4, red: 12)) ==
               tiles(black: 7, blue: 4, blue: 8, red: 11, red: 12)
    end

    test "a joker can be used to fill a gap in the middle" do
      assert Set.sort(tiles(black: :joker, red: 10, red: 8)) ==
               tiles(red: 8, black: :joker, red: 10)
    end

    test "a joker defaults to fill in at the top" do
      assert Set.sort(tiles(orange: 6, orange: 5, black: :joker)) ==
               tiles(orange: 5, orange: 6, black: :joker)
    end

    test "a joker fills at the bottom if the top is full" do
      assert Set.sort(tiles(orange: 12, orange: 13, black: :joker)) ==
               tiles(black: :joker, orange: 12, orange: 13)
    end

    test "two jokers filling at the top" do
      assert Set.sort(tiles(blue: 10, orange: :joker, blue: 11, black: :joker)) ==
               tiles(blue: 10, blue: 11, black: :joker, orange: :joker)
    end

    test "two jokers, first one at the top, second at the bottom" do
      assert Set.sort(tiles(blue: 11, orange: :joker, blue: 12, black: :joker)) ==
               tiles(orange: :joker, blue: 11, blue: 12, black: :joker)
    end

    test "two jokers, both at the bottom" do
      assert Set.sort(tiles(red: 12, orange: :joker, red: 13, black: :joker)) ==
               tiles(black: :joker, orange: :joker, red: 12, red: 13)
    end
  end

  describe "Set.value/1" do
    test "value of a simple group" do
      assert Set.value(tiles(red: 3, blue: 3, black: 3)) == 3 + 3 + 3
    end

    test "value of a four-piece group" do
      assert Set.value(tiles(red: 3, blue: 3, black: 3, orange: 3)) == 3 + 3 + 3 + 3
    end

    test "value of a group with a joker" do
      assert Set.value(tiles(red: 9, black: :joker, orange: 9)) == 9 + 9 + 9
    end

    test "value of a group with two jokers" do
      assert Set.value(tiles(orange: :joker, red: 9, black: :joker, orange: 9)) == 9 + 9 + 9 + 9
    end

    test "value of a simple run" do
      assert Set.value(tiles(red: 7, red: 8, red: 9)) == 7 + 8 + 9
    end

    test "value of a run with a joker" do
      assert Set.value(tiles(red: 7, red: 8, orange: :joker)) == 7 + 8 + 9
    end

    test "value of a run with two jokers (one at top)" do
      assert Set.value(tiles(orange: 11, black: :joker, orange: 12, blue: :joker)) ==
               10 + 11 + 12 + 13
    end
  end

  defp tiles(tuples) do
    for {color, value} <- tuples, do: Tile.new(:dummy_id, color, value)
  end
end
