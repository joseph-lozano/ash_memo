defmodule AshMemo.Domain do
  use Ash.Domain,
    extensions: [AshPostgres.Domain],
    validate_config_inclusion?: false

  @moduledoc """
  Domain for AshMemo cache entry resources.

  This domain exists solely to allow AshPostgres to discover
  cache entry resources for migration generation.
  """

  resources do
    resource(AshMemo.CacheEntry)
  end
end
