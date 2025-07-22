# AshMemo Implementation Specification

## Overview
Build an Elixir library called AshMemo that extends the Ash framework to provide caching for calculations. The library intercepts calculation execution to cache results in PostgreSQL with configurable TTL and eviction strategies.

## Core Requirements
- **Name**: ash_memo (package name), AshMemo (module namespace)
- **Purpose**: Cache Ash calculation results with opt-in configuration per calculation
- **Storage**: PostgreSQL table with composite key (resource, resource_primary_key, calculation_name)
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
```elixir
# Create a Spark.Dsl.Extension that adds a :memo section
# Define @cache_calculation entity with :name and :ttl options
# Schema should include:
#   - cache_resource (default: AshMemo.CacheEntry)
#   - ttl (default: 1 hour in milliseconds)
#   - eviction_strategy (default: :fifo, also supports :lru)
# Add transformer: AshMemo.Transformers.WrapCalculations
```

### 2. Database Schema (lib/ash_memo/cache_entry.ex)
```elixir
# Ash resource with AshPostgres.DataLayer
# Table: ash_cache_entries
# Composite primary key: [:resource, :resource_primary_key, :calculation_name]
# Fields:
#   - resource: :string (resource module name)
#   - resource_primary_key: :string (serialized primary key)
#   - calculation_name: :string
#   - value: AshMemo.ErlangTerm (custom Ecto type)
#   - inserted_at: :utc_datetime_usec
#   - expires_at: :utc_datetime_usec
#   - accessed_at: :utc_datetime_usec (for LRU)
#   - access_count: :integer (default: 1, for LRU)
# Actions: read, destroy, upsert (with upsert_identity), touch (updates accessed_at)
# Create indexes on: expires_at, accessed_at, inserted_at
```

### 3. Binary Storage Type (lib/ash_memo/erlang_term.ex)
```elixir
# Implement Ecto.Type behaviour
# Use :erlang.term_to_binary/2 with [:compressed] option for dump
# Use :erlang.binary_to_term/1 for load
# Handle errors gracefully
```

### 4. Calculation Wrapper (lib/ash_memo/cached_calculation.ex)
```elixir
# Use Ash.Resource.Calculation
# init/1: Extract cache_key, ttl, delegate calculation
# load/3: Delegate to wrapped calculation
# calculate/3: 
#   - Build cache key from resource + record IDs + calculation name
#   - Check cache with AshMemo.Cache.get/1
#   - On miss: calculate, then store with AshMemo.Cache.put/3
#   - On hit: spawn Task to update accessed_at asynchronously
```

### 5. Transformer (lib/ash_memo/transformers/wrap_calculations.ex)
```elixir
# Implement Spark.Dsl.Transformer
# For each cached calculation in DSL:
#   - Get original calculation definition
#   - Replace with {AshMemo.CachedCalculation, opts} including delegate
```

### 6. Background Cleanup (lib/ash_memo/cleaner.ex)
```elixir
# GenServer that schedules periodic cleanup
# Two timers: TTL cleanup (15 min) and size cleanup (1 hour)
# TTL cleanup: Delete where expires_at < now, batch size 1000
# Size cleanup: If count > max_entries, evict oldest 10%
# FIFO: Sort by inserted_at ASC
# LRU: Sort by accessed_at ASC, access_count ASC
# Use Ash.bulk_destroy with strategy: :atomic
```

### 7. Configuration (lib/ash_memo/config.ex)
```elixir
# repo/0 function that reads from Application.get_env(:ash_memo, :repo)
# Raise clear error if not configured
```

### 8. Domain (lib/ash_memo/domain.ex)
```elixir
# Simple Ash.Domain with AshPostgres.Domain extension
# Include AshMemo.CacheEntry resource
```

### 9. Mix Configuration
```elixir
# Dependencies: ash ~> 3.0, spark ~> 2.0, ash_postgres ~> 2.0 (optional)
# Optional: oban ~> 2.15 (for future enhancement)
# Description and package info for Hex publishing
```

## Installation Instructions for Users
1. Add `{:ash_memo, "~> 0.1.0"}` to deps
2. Configure repo: `config :ash_memo, repo: MyApp.Repo`
3. Add to supervision tree: `children = [..., AshMemo.Supervisor]`
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
