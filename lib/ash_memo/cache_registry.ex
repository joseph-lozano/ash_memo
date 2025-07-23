defmodule AshMemo.CacheRegistry do
  @moduledoc """
  Registry for looking up cache entry resources by repo.

  Cache entry resources are dynamically created by the transformer
  for each repo that has resources with cached calculations.
  """

  @doc """
  Gets the cache entry resource module for a given repo.

  For now, we use a single cache entry resource for all repos.
  In the future, this could be extended to support per-repo cache tables.
  """
  def resource_for_repo(_repo) do
    AshMemo.CacheEntry
  end
end
