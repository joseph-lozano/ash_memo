defmodule AshMemoTest do
  use ExUnit.Case
  doctest AshMemo

  test "greets the world" do
    assert AshMemo.hello() == :world
  end
end
