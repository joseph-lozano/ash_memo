# AshMemo Implementation Specification

## Overview

Build an Elixir library called AshMemo that extends the Ash framework to provide caching for calculations. The library intercepts calculation execution to cache results in PostgreSQL with configurable TTL and eviction strategies.

## Core Requirements

- **Name**: ash_memo (package name), AshMemo (module namespace)
- **Purpose**: Cache Ash calculation results with opt-in configuration per calculation
- **Storage**: PostgreSQL table with single string cache key for efficient batch operations
- **Eviction**: Time-based expiry + FIFO/LRU when table exceeds size limit
- **Integration**: Users add AshMemo.Supervisor to supervision tree and AshMemo.Domain to ash_domains config

## Project Structure

```
ash_memo/
├── lib/
│   ├── ash_memo.ex                    # Public API module
│   └── ash_memo/
│       ├── domain.ex                   # Ash domain definition
│       ├── resource.ex                 # DSL extension (use Spark.Dsl.Extension)
│       ├── cache.ex                    # Core caching logic (get/put/touch operations)
│       ├── cache_entry.ex              # Ash resource for cache entries table
│       ├── cached_calculation.ex       # Calculation wrapper module
│       ├── erlang_term.ex              # Ecto.Type for binary storage
│       ├── info.ex                     # Spark introspection functions
│       ├── config.ex                   # Configuration helpers
│       ├── supervisor.ex               # OTP supervisor
│       ├── cleaner.ex                  # GenServer for background cleanup
│       └── transformers/
│           └── wrap_calculations.ex    # Spark transformer to wrap calculations
├── test/
├── mix.exs
└── README.md
```

## Key Implementation Details

### 1. DSL Extension (lib/ash_memo/resource.ex)

Create a Spark.Dsl.Extension that adds a `:memo` section with the following structure:

```elixir
defmodule AshMemo.Resource do
  use Spark.Dsl.Extension,
    sections: [@memo],
    transformers: [AshMemo.Transformers.WrapCalculations]

  # Define @cache_calculation entity with :name and :ttl options
  # Schema includes:
  #   - cache_resource (default: AshMemo.CacheEntry)
  #   - ttl (default: nil = no expiration)
  #   - eviction_strategy (default: :fifo, also supports :lru)
end
```

### 2. Database Schema (lib/ash_memo/cache_entry.ex)

Define an Ash resource with AshPostgres data layer for cache storage:

```elixir
defmodule AshMemo.CacheEntry do
  use Ash.Resource,
    domain: AshMemo.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "ash_memo_cache_entries"
    repo &AshMemo.Config.repo/0
  end

  attributes do
    attribute :cache_key, :string, allow_nil?: false, primary_key?: true
    attribute :value, Ash.Type.Term
    attribute :byte_size, :integer, allow_nil?: false
    attribute :inserted_at, :utc_datetime_usec, default: &DateTime.utc_now/0
    attribute :expires_at, :utc_datetime_usec, allow_nil?: true
    attribute :accessed_at, :utc_datetime_usec, default: &DateTime.utc_now/0
    attribute :access_count, :integer, default: 1
  end

  actions do
    defaults [:read, :destroy]

    create :upsert do
      upsert? true
      upsert_identity :cache_key
    end

    update :touch do
      change set_attribute(:accessed_at, &DateTime.utc_now/0)
      change increment(:access_count)
    end
  end

  postgres do
    index [:expires_at]  # For TTL cleanup
    index [:inserted_at, :accessed_at]  # For FIFO/LRU eviction
  end
end
```

### 3. Binary Storage Type (Using Ash.Type.Term)

We'll leverage the built-in `Ash.Type.Term` which already handles storing arbitrary Erlang terms as binaries. We'll create a utility module to provide the byte size calculation functionality:

```elixir
defmodule AshMemo.TermUtils do
  @moduledoc """
  Utility functions for working with Erlang terms in the cache.
  """

  @doc """
  Returns the byte size of the term when stored as a binary.
  This is used to track cache entry sizes for eviction policies.
  """
  def byte_size(value) do
    try do
      value
      |> :erlang.term_to_binary()
      |> byte_size()
    rescue
      _ -> 0
    end
  end
end
```

### 4. Calculation Wrapper (lib/ash_memo/cached_calculation.ex)

Wrap calculations to add caching behavior with efficient batch operations:

```elixir
defmodule AshMemo.CachedCalculation do
  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    {:ok, %{
      cache_key: opts[:cache_key],
      ttl: opts[:ttl],
      delegate: opts[:delegate],
      eviction_strategy: opts[:eviction_strategy]
    }}
  end

  @impl true
  def load(query, opts, context) do
    # Delegate loading to the wrapped calculation
    delegate = opts[:delegate]
    delegate.load(query, opts, context)
  end

  @impl true
  def calculate(records, opts, context) do
    return [] if records == []

    resource = List.first(records).__struct__
    calculation_name = opts[:cache_key]

    # Step 1: Build cache keys for all records
    cache_entries = Enum.map(records, fn record ->
      cache_key = AshMemo.Cache.build_cache_key(resource, record, calculation_name)
      {record, cache_key}
    end)

    cache_keys = Enum.map(cache_entries, &elem(&1, 1))

    # Step 2: Batch lookup all cache entries
    cached_values = AshMemo.Cache.get_many(cache_keys)

    # Step 3: Separate hits and misses
    {hits, misses} =
      cache_entries
      |> Enum.zip(cached_values)
      |> Enum.split_with(fn {_, value} -> value != :miss end)

    # Step 4: Handle cache hits (async touch)
    if hits != [] do
      hit_keys = Enum.map(hits, fn {{_, key}, _} -> key end)
      Task.start(fn -> AshMemo.Cache.touch_many(hit_keys) end)
    end

    # Step 5: Calculate misses if any
    miss_results = if misses == [] do
      []
    else
      miss_records = Enum.map(misses, fn {{record, _}, _} -> record end)
      calculated_values = opts[:delegate].calculate(miss_records, opts, context)

      # Step 6: Batch cache the results
      cache_data =
        misses
        |> Enum.zip(calculated_values)
        |> Enum.map(fn {{{_, cache_key}, _}, value} ->
          %{
            cache_key: cache_key,
            value: value,
            byte_size: AshMemo.TermUtils.byte_size(value)
          }
        end)

      AshMemo.Cache.put_many(cache_data, opts[:ttl])

      # Return tuples of record and calculated value
      misses
      |> Enum.zip(calculated_values)
      |> Enum.map(fn {{{record, _}, _}, value} -> {record, value} end)
    end

    # Step 7: Build result map for efficient lookup
    result_map = Map.new(miss_results)

    # Step 8: Assemble final results in original order
    Enum.map(records, fn record ->
      case Enum.find(hits, fn {{r, _}, _} -> r == record end) do
        {_, value} -> value
        nil -> Map.fetch!(result_map, record)
      end
    end)
  end
end
```

### 5. Cache Operations (lib/ash_memo/cache.ex)

Core caching logic with batch operations support:

```elixir
defmodule AshMemo.Cache do
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
  def get_many(cache_keys) when is_list(cache_keys) do
    return [] if cache_keys == []

    now = DateTime.utc_now()

    # Single query to fetch all entries
    entries =
      AshMemo.CacheEntry
      |> Ash.Query.filter(cache_key in ^cache_keys and (is_nil(expires_at) or expires_at > ^now))
      |> Ash.read!()

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
  def put_many(entries, ttl) when is_list(entries) do
    return :ok if entries == []

    expires_at = if ttl do
      DateTime.add(DateTime.utc_now(), ttl, :millisecond)
    else
      nil
    end

    # Add expires_at to all entries
    create_data = Enum.map(entries, fn entry ->
      Map.put(entry, :expires_at, expires_at)
    end)

    # Bulk upsert
    Ash.bulk_create!(
      AshMemo.CacheEntry,
      create_data,
      :upsert,
      upsert?: true,
      upsert_identity: :cache_key,
      upsert_fields: [:value, :byte_size, :expires_at, :accessed_at, :access_count]
    )

    :ok
  end

  @doc """
  Batch touch multiple cache entries to update accessed_at and increment access_count.
  """
  def touch_many(cache_keys) when is_list(cache_keys) do
    return :ok if cache_keys == []

    AshMemo.CacheEntry
    |> Ash.Query.filter(cache_key in ^cache_keys)
    |> Ash.bulk_update!(
      :touch,
      %{},
      strategy: :atomic,
      atomic_update: %{
        accessed_at: DateTime.utc_now(),
        access_count: expr(access_count + 1)
      }
    )

    :ok
  end

  # Single-key operations (for backwards compatibility if needed)
  def get(cache_key), do: get_many([cache_key]) |> List.first()

  def put(cache_key, value, byte_size, ttl) do
    put_many([%{cache_key: cache_key, value: value, byte_size: byte_size}], ttl)
  end

  def touch(cache_key), do: touch_many([cache_key])
end
```

### 6. Transformer (lib/ash_memo/transformers/wrap_calculations.ex)

Transform calculations to use caching wrapper:

```elixir
defmodule AshMemo.Transformers.WrapCalculations do
  use Spark.Dsl.Transformer

  @impl true
  def transform(dsl) do
    cached_calculations = AshMemo.Info.cached_calculations(dsl)

    Enum.reduce_while(cached_calculations, {:ok, dsl}, fn cached_calc, {:ok, dsl} ->
      calculation_name = cached_calc.name
      original_calc = Ash.Resource.Info.calculation(dsl, calculation_name)

      wrapped_opts = [
        delegate: original_calc.calculation,
        ttl: cached_calc.ttl,
        eviction_strategy: cached_calc.eviction_strategy,
        cache_key: calculation_name
      ]

      # Replace calculation with wrapped version
      dsl = Ash.Resource.Builder.replace_calculation(
        dsl,
        calculation_name,
        {AshMemo.CachedCalculation, wrapped_opts}
      )

      {:cont, {:ok, dsl}}
    end)
  end
end
```

### 7. Background Cleanup (lib/ash_memo/cleaner.ex)

GenServer for periodic cache maintenance:

```elixir
defmodule AshMemo.Cleaner do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    # Schedule TTL cleanup every 15 minutes
    Process.send_after(self(), :ttl_cleanup, :timer.minutes(15))
    # Schedule size cleanup every hour
    Process.send_after(self(), :size_cleanup, :timer.hours(1))

    {:ok, %{
      max_entries: opts[:max_entries] || :unlimited,
      max_bytes: opts[:max_bytes] || 256 * 1024 * 1024, # 256MB default
      batch_size: opts[:batch_size] || 1000
    }}
  end

  @impl true
  def handle_info(:ttl_cleanup, state) do
    # Delete expired entries (only those with non-nil expires_at)
    query =
      AshMemo.CacheEntry
      |> Ash.Query.filter(not is_nil(expires_at) and expires_at < ^DateTime.utc_now())
      |> Ash.Query.limit(state.batch_size)

    Ash.bulk_destroy(query, :destroy, %{}, strategy: :atomic)

    # Reschedule
    Process.send_after(self(), :ttl_cleanup, :timer.minutes(15))
    {:noreply, state}
  end

  @impl true
  def handle_info(:size_cleanup, state) do
    # Check both entry count and total byte size
    stats = get_cache_stats()

    needs_eviction =
      (state.max_entries != :unlimited && stats.count > state.max_entries) ||
      (state.max_bytes != :unlimited && stats.total_bytes > state.max_bytes)

    if needs_eviction do
      # Calculate how much to evict (10% of entries or enough to get under byte limit)
      entries_to_evict = if state.max_entries != :unlimited do
        div(stats.count, 10)
      else
        100  # Default batch size when only byte limit is set
      end

      bytes_to_evict = if state.max_bytes != :unlimited && stats.total_bytes > state.max_bytes do
        stats.total_bytes - state.max_bytes
      else
        0
      end

      evict_entries(entries_to_evict, bytes_to_evict)
    end

    # Reschedule
    Process.send_after(self(), :size_cleanup, :timer.hours(1))
    {:noreply, state}
  end

  defp get_cache_stats do
    # Get count and sum of byte sizes
    AshMemo.CacheEntry
    |> Ash.aggregate(
      count: {:count, :cache_key},
      total_bytes: {:sum, :byte_size}
    )
    |> Ash.read_one!()
    |> case do
      nil -> %{count: 0, total_bytes: 0}
      stats -> stats
    end
  end

  defp evict_entries(min_entries, min_bytes) do
    query =
      AshMemo.CacheEntry
      |> Ash.Query.sort([:inserted_at, :accessed_at])  # FIFO primary, LRU secondary

    # If we need to evict based on bytes, fetch entries until we've evicted enough
    if min_bytes > 0 do
      evict_until_bytes_freed(query, min_bytes, min_entries)
    else
      # Just evict the minimum number of entries
      query
      |> Ash.Query.limit(min_entries)
      |> Ash.bulk_destroy(:destroy, %{}, strategy: :atomic)
    end
  end

  defp evict_until_bytes_freed(query, bytes_needed, min_entries, offset \\ 0, bytes_freed \\ 0) do
    batch_size = 100

    batch_query =
      query
      |> Ash.Query.offset(offset)
      |> Ash.Query.limit(batch_size)

    entries = Ash.read!(batch_query)

    if Enum.empty?(entries) || (bytes_freed >= bytes_needed && offset >= min_entries) do
      # We're done
      :ok
    else
      # Calculate bytes in this batch
      batch_bytes = Enum.sum(Enum.map(entries, & &1.byte_size))

      # Delete this batch
      cache_keys = Enum.map(entries, & &1.cache_key)
      AshMemo.CacheEntry
      |> Ash.Query.filter(cache_key in ^cache_keys)
      |> Ash.bulk_destroy(:destroy, %{}, strategy: :atomic)

      # Continue if needed
      evict_until_bytes_freed(
        query,
        bytes_needed,
        min_entries,
        offset + batch_size,
        bytes_freed + batch_bytes
      )
    end
  end
end
```

### 8. Configuration (lib/ash_memo/config.ex)

Configuration helpers with clear error messages:

```elixir
defmodule AshMemo.Config do
  def repo do
    case Application.get_env(:ash_memo, :repo) do
      nil ->
        raise """
        AshMemo requires a repo to be configured.

        Please add the following to your config:

            config :ash_memo, repo: YourApp.Repo
        """

      repo -> repo
    end
  end
end
```

### 9. Domain (lib/ash_memo/domain.ex)

Simple domain definition for the cache resources:

```elixir
defmodule AshMemo.Domain do
  use Ash.Domain,
    extensions: [AshPostgres.Domain]

  resources do
    resource AshMemo.CacheEntry
  end
end
```

### 10. Mix Configuration

Mix project configuration with proper dependencies:

```elixir
defmodule AshMemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_memo,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Caching extension for Ash Framework calculations",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ash, "~> 3.0"},
      {:spark, "~> 2.0"},
      {:ash_postgres, "~> 2.0", optional: true},
      {:oban, "~> 2.15", optional: true},  # Future enhancement
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/your-org/ash_memo"},
      maintainers: ["Your Name"]
    ]
  end
end
```

## Cache Configuration Options

Users can configure global cache limits when starting the supervisor:

```elixir
children = [
  # ... other children
  {AshMemo.Supervisor,
    max_entries: 50_000,      # Maximum number of cache entries (default: :unlimited)
    max_bytes: 512 * 1024 * 1024  # Maximum cache size in bytes (default: 256MB)
  }
]
```

Configuration options:

- `max_entries`: Maximum number of cache entries. Defaults to `:unlimited`
- `max_bytes`: Maximum total size of cache in bytes. Defaults to `268_435_456` (256MB)
- `batch_size`: Batch size for cleanup operations. Defaults to `1000`

When cache limits are exceeded, the cleaner will evict entries using FIFO strategy (oldest `inserted_at` first, with `accessed_at` as secondary sort for LRU behavior).

## Installation Instructions for Users

1. Add `{:ash_memo, "~> 0.1.0"}` to deps
2. Configure repo: `config :ash_memo, repo: MyApp.Repo`
3. Add to supervision tree: `children = [..., AshMemo.Supervisor]` (or with options as shown above)
4. Add to ash domains: `config :my_app, ash_domains: [..., AshMemo.Domain]`
5. Run `mix ash.codegen` and `mix ecto.migrate`
6. Use in resources:

   ```elixir
   use Ash.Resource, extensions: [AshMemo.Resource]

   memo do
     cache_calculation :expensive_calculation do
       ttl :timer.minutes(30)
     end
   end
   ```

## Testing Considerations

- Test cache hit/miss scenarios
- Test TTL expiration
- Test FIFO eviction when table exceeds max size
- Test concurrent access patterns
- Benchmark performance improvements

## Important Notes

- Do NOT use UNLOGGED tables (breaks read replicas)
- Use dynamic repo lookup via module function
- Ensure transformer only wraps calculations explicitly marked for caching
- Handle nil/error cases gracefully in cache operations
- Use Task.start for async operations to avoid blocking

## Future Enhancements (v1)

- Detect Oban availability and use for scheduling if present
- Add LRU eviction strategy using accessed_at and access_count
- Add telemetry events for monitoring
- Support cache warming strategies
- Add cache invalidation hooks
