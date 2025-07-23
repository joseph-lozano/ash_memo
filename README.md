# AshMemo

> ⚠️ **WARNING: This library is under active development and not yet ready for production use!**
>
> **Working features:**
>
> - ✅ Basic caching with DSL configuration
> - ✅ Cache storage and retrieval
> - ✅ Batch operations for performance
>
> **Not yet implemented:**
>
> - ❌ Supervisor and background processes
> - ❌ TTL expiration (TTL is stored but not enforced)
> - ❌ Size-based eviction limits
> - ❌ Cache cleanup processes

AshMemo is a caching extension for [Ash Framework](https://ash-hq.org/) that automatically caches calculation results in PostgreSQL. It provides transparent caching with configurable TTL (Time To Live) and automatic eviction strategies, significantly improving performance for expensive calculations.

## Features

- **Transparent Caching**: Simply mark calculations for caching in your resource DSL
- **PostgreSQL Storage**: Leverages your existing database for reliable cache storage
- **Configurable TTL**: Set expiration times per calculation
- **Automatic Eviction**: FIFO and LRU strategies with configurable size limits
- **Batch Operations**: Optimized for bulk queries with efficient batch lookups
- **Zero Configuration**: Works out of the box with sensible defaults

## Installation

Add `ash_memo` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_memo, "~> 0.1.0"}
  ]
end
```

## Setup

### 1. Add AshMemo Supervisor

Add the AshMemo supervisor to your application's supervision tree. This manages background cache cleanup tasks.

```elixir
# lib/my_app/application.ex
def start(_type, _args) do
  children = [
    # ... your other supervisors
    MyApp.Repo,
    {AshMemo.Supervisor,
      # Optional configuration
      max_entries: 50_000,           # Maximum cache entries (default: unlimited)
      max_bytes: 512 * 1024 * 1024   # Maximum cache size in bytes (default: 256MB)
    }
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### 2. Add AshMemo Domain

Register the AshMemo domain in your application configuration:

```elixir
# config/config.exs
config :my_app, ash_domains: [
  MyApp.Domain,
  # ... your other domains
  AshMemo.Domain
]
```

### 3. Run Migrations

Generate and run the migration to create the cache table:

```bash
mix ash.codegen --name add_ash_memo_cache
mix ecto.migrate
```

## Usage

### Basic Example

Add the AshMemo extension to your resource and mark calculations for caching:

```elixir
defmodule MyApp.Posts.Post do
  use Ash.Resource,
    domain: MyApp.Posts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshMemo.Resource]

  postgres do
    table "posts"
    repo MyApp.Repo
  end

  # Configure which calculations to cache
  memo do
    cache_calculation :word_count do
      ttl :timer.minutes(30)  # Cache for 30 minutes
    end

    cache_calculation :sentiment_score do
      ttl :timer.hours(24)    # Cache for 24 hours
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :content, :string, public?: true
  end

  calculations do
    # This expensive calculation will be cached
    calculate :word_count, :integer do
      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          case record.content do
            nil -> 0
            content -> length(String.split(content, ~r/\s+/, trim: true))
          end
        end)
      end
    end

    # This calculation is also cached
    calculate :sentiment_score, :float do
      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          # Expensive sentiment analysis logic here
          analyze_sentiment(record.content)
        end)
      end
    end

    # This calculation is NOT cached (not listed in memo block)
    calculate :character_count, :integer do
      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          String.length(record.content || "")
        end)
      end
    end
  end
end
```

### Querying Cached Calculations

Use cached calculations exactly like regular calculations:

```elixir
# Single record with cached calculation
post = MyApp.Posts.Post
  |> Ash.Query.filter(id == ^post_id)
  |> Ash.Query.load(:word_count)
  |> Ash.read_one!()

# Bulk query - AshMemo automatically batches cache lookups
posts = MyApp.Posts.Post
  |> Ash.Query.load([:word_count, :sentiment_score])
  |> Ash.read!()
```

The first time a calculation is requested, it's computed and cached. Subsequent requests use the cached value until the TTL expires.

## Configuration Options

### Supervisor Options

Configure global cache limits when starting the supervisor:

```elixir
{AshMemo.Supervisor,
  max_entries: 100_000,        # Maximum number of cache entries
  max_bytes: 1024 * 1024 * 1024,  # Maximum cache size (1GB)
  batch_size: 1000             # Cleanup batch size
}
```

### Cache Calculation Options

Configure individual calculations in the `memo` block:

```elixir
memo do
  cache_calculation :my_calculation do
    ttl :timer.minutes(15)           # Required: expiration time
    eviction_strategy :fifo          # Optional: :fifo (default) or :lru
  end
end
```

### TTL Configuration

TTL (Time To Live) is specified in milliseconds. Use Erlang's `:timer` module for readability:

```elixir
ttl :timer.seconds(30)      # 30 seconds
ttl :timer.minutes(5)       # 5 minutes
ttl :timer.hours(2)         # 2 hours
ttl 60_000                  # 60 seconds (raw milliseconds)
```

## How It Works

1. **Cache Key Generation**: Each cached value is stored with a deterministic key based on:
   - Resource module name
   - Record primary key value(s)
   - Calculation name

2. **Batch Operations**: When loading calculations for multiple records, AshMemo:
   - Performs a single database query to fetch all relevant cache entries
   - Identifies cache hits and misses
   - Calculates only the misses
   - Stores new results in a single bulk insert

3. **Background Cleanup**: A GenServer runs periodic maintenance:
   - Removes expired entries every 15 minutes
   - Enforces size limits hourly using FIFO eviction

4. **Access Tracking**: Cache hits update `accessed_at` timestamp and increment `access_count` for future LRU support.

## Performance Considerations

- **Database Impact**: Cache queries add minimal overhead - typically a single indexed lookup
- **Batch Efficiency**: Bulk operations make caching efficient even for large datasets
- **Memory Usage**: Cache data is stored in PostgreSQL, not application memory
- **Network Overhead**: Consider network latency when caching very simple calculations

## Troubleshooting

### Cache Not Working

1. Ensure the supervisor is started in your application
2. Verify the migration created the `ash_memo_cache_entries` table
3. Check that calculations are properly listed in the `memo` block
4. Confirm your repo is configured correctly

### Performance Issues

1. Monitor cache hit rates by querying the cache table
2. Adjust TTL values based on data volatility
3. Set appropriate size limits to prevent unbounded growth
4. Consider if the calculation is expensive enough to warrant caching

### Debugging

Query the cache table directly to inspect entries:

```elixir
import Ecto.Query

MyApp.Repo.all(
  from c in "ash_memo_cache_entries",
  where: c.cache_key like "Example.Posts.Post:%",
  select: %{
    key: c.cache_key,
    size: c.byte_size,
    created: c.inserted_at,
    accessed: c.accessed_at,
    hits: c.access_count
  }
)
```

## License

This project is licensed under the MIT License.
