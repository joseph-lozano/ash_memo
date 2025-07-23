defmodule AshMemo.TermUtils do
  @moduledoc """
  Utility functions for working with Erlang terms in the cache.
  """

  @doc """
  Returns the byte size of the term when stored as a binary.
  This is used to track cache entry sizes for eviction policies.

  ## Examples

      iex> AshMemo.TermUtils.byte_size("hello")
      11

      iex> AshMemo.TermUtils.byte_size(%{a: 1, b: 2})
      16

      iex> AshMemo.TermUtils.byte_size([1, 2, 3])
      7

  """
  def byte_size(value) do
    try do
      value
      |> :erlang.term_to_binary()
      |> Kernel.byte_size()
    rescue
      _ -> 0
    end
  end
end
