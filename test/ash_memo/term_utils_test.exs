defmodule AshMemo.TermUtilsTest do
  use ExUnit.Case
  doctest AshMemo.TermUtils

  describe "byte_size/1" do
    test "returns byte size for strings" do
      assert AshMemo.TermUtils.byte_size("hello") == 11
      assert AshMemo.TermUtils.byte_size("") == 6
    end

    test "returns byte size for integers" do
      assert AshMemo.TermUtils.byte_size(0) == 3
      assert AshMemo.TermUtils.byte_size(42) == 3
      assert AshMemo.TermUtils.byte_size(1_000_000) == 6
    end

    test "returns byte size for atoms" do
      assert AshMemo.TermUtils.byte_size(:ok) == 5
      assert AshMemo.TermUtils.byte_size(:some_longer_atom) == 19
    end

    test "returns byte size for lists" do
      assert AshMemo.TermUtils.byte_size([]) == 2
      assert AshMemo.TermUtils.byte_size([1, 2, 3]) == 7
    end

    test "returns byte size for maps" do
      assert AshMemo.TermUtils.byte_size(%{}) == 6
      assert AshMemo.TermUtils.byte_size(%{a: 1, b: 2}) > 6
    end

    test "returns byte size for tuples" do
      assert AshMemo.TermUtils.byte_size({:ok, "value"}) == 17
    end

    test "returns byte size for complex nested structures" do
      data = %{
        user: %{
          id: 123,
          name: "Test User",
          emails: ["test@example.com"],
          active: true
        },
        metadata: %{
          created_at: ~N[2024-01-01 00:00:00],
          tags: [:important, :verified]
        }
      }

      size = AshMemo.TermUtils.byte_size(data)
      assert size > 100
    end

    test "returns actual byte size for function references" do
      # Function references can actually be serialized
      fun = fn -> :ok end
      assert AshMemo.TermUtils.byte_size(fun) > 0
    end

    test "handles nil values" do
      assert AshMemo.TermUtils.byte_size(nil) == 6
    end

    test "handles large binary data" do
      binary = :crypto.strong_rand_bytes(1024)
      size = AshMemo.TermUtils.byte_size(binary)
      # Binary representation includes some overhead
      assert size > 1024
    end
  end
end
