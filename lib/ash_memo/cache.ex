defmodule AshMemo.Cache do
  require Ash.Query

  @doc """
  Generates a deterministic cache key from components.
  Format: "ModuleName:primary_key_value:calculation_name"
  """
  def build_cache_key(resource, record, calculation_name) do
    resource_name = inspect(resource)

    primary_key =
      resource
      |> Ash.Resource.Info.primary_key()
      |> Enum.map(fn key -> Map.get(record, key) end)
      |> Enum.join(":")

    "#{resource_name}:#{primary_key}:#{calculation_name}"
  end

  @doc """
  Batch lookup multiple cache entries. Returns values in same order as keys,
  with :miss for not found or expired entries.
  """
  def get_many([], _resource), do: []

  def get_many(cache_keys, _resource) when is_list(cache_keys) do
    # For now, use AshMemo.CacheEntry directly
    # Later this will be dynamic based on the resource's repo
    now = DateTime.utc_now()

    # Single query to fetch all entries
    entries =
      AshMemo.CacheEntry
      |> Ash.Query.filter(cache_key in ^cache_keys and (is_nil(expires_at) or expires_at > ^now))
      |> Ash.read!(domain: AshMemo.Domain)

    # Convert to map for O(1) lookup
    entries_by_key = Map.new(entries, fn entry -> {entry.cache_key, entry.value} end)

    # Return results in same order as input, with :miss for not found
    Enum.map(cache_keys, fn key ->
      Map.get(entries_by_key, key, :miss)
    end)
  end

  @doc """
  Batch insert/update multiple cache entries.
  """
  def put_many([], _ttl, _resource), do: :ok

  def put_many(entries, ttl, _resource) when is_list(entries) do
    # For now, use AshMemo.CacheEntry directly
    # Later this will be dynamic based on the resource's repo

    expires_at =
      if ttl do
        DateTime.add(DateTime.utc_now(), ttl, :millisecond)
      else
        nil
      end

    # Add expires_at to all entries
    create_data =
      Enum.map(entries, fn entry ->
        Map.put(entry, :expires_at, expires_at)
      end)

    # Bulk upsert
    Ash.bulk_create!(
      create_data,
      AshMemo.CacheEntry,
      :upsert,
      domain: AshMemo.Domain,
      upsert?: true,
      upsert_identity: :cache_key,
      upsert_fields: [:value, :byte_size, :expires_at, :accessed_at, :access_count],
      return_errors?: true
    )

    :ok
  end

  @doc """
  Batch touch multiple cache entries to update accessed_at and increment access_count.
  """
  def touch_many([], _resource), do: :ok

  def touch_many(cache_keys, _resource) when is_list(cache_keys) do
    # For now, use AshMemo.CacheEntry directly
    # Later this will be dynamic based on the resource's repo

    AshMemo.CacheEntry
    |> Ash.Query.filter(cache_key in ^cache_keys)
    |> Ash.bulk_update!(
      :touch,
      %{},
      domain: AshMemo.Domain,
      strategy: :atomic
    )

    :ok
  end
end
