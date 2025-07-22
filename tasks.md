# AshMemo v0 Implementation Tasks

## Phase 1: Basic Project Setup & Compilation
### Task 1.1: Initialize Mix Project
- [x] Create mix.exs with basic project structure
- [x] Add minimal dependencies (ash, spark)
- [x] Ensure `mix compile` works
- [x] Create empty lib/ash_memo.ex module

### Task 1.2: Create Minimal DSL Extension
- [x] Create lib/ash_memo/resource.ex with empty Spark.Dsl.Extension
- [x] Define memo section with no entities yet
- [x] Update example project to use the extension without errors

## Phase 2: DSL Structure (No Functionality)
### Task 2.1: Define cache_calculation Entity
- [x] Add cache_calculation entity to memo section
- [x] Define schema with :name (required) and :ttl (optional)
- [x] Update example Post resource to use cache_calculation DSL

### Task 2.2: Add Info Module for Introspection
- [x] Create lib/ash_memo/info.ex using Spark.Dsl.Fragment
- [x] Implement cached_calculations/1 function
- [x] Add example demonstrating introspection of cached calculations

## Phase 3: Cache Entry Resource (Storage Layer)
### Task 3.1: Create Term Utilities
- [x] Create lib/ash_memo/term_utils.ex with byte_size/1 function
- [x] Update example to show how byte sizes are tracked using Ash.Type.Term

### Task 3.2: Define CacheEntry Resource
- [x] Create lib/ash_memo/cache_entry.ex with attributes
- [x] Add cache_key as single primary key
- [x] Add byte_size attribute to track cache entry size
- [x] Add CacheEntry to example project's domain

### Task 3.3: Create Domain
- [x] Create lib/ash_memo/domain.ex
- [x] Add CacheEntry to domain resources
- [x] Update example to use AshMemo domain

## Phase 4: Calculation Wrapper (Always Miss)
### Task 5.1: Create CachedCalculation Module
- [x] Create lib/ash_memo/cached_calculation.ex
- [x] Implement init/1 to store options
- [x] Update example to show wrapped calculation behavior

### Task 5.2: Implement Calculate (Always Delegate)
- [x] Implement calculate/3 that always delegates
- [x] Update example to demonstrate delegation

### Task 5.3: Implement Load Delegation
- [x] Implement load/3 to delegate to wrapped calculation
- [x] Add example showing load behavior

## Phase 5: Transformer Integration
### Task 6.1: Basic Transformer
- [x] Create lib/ash_memo/transformers/wrap_calculations.ex
- [x] Implement transform/1 to find cached calculations
- [x] Update example to show transformer in action

### Task 6.2: Calculation Replacement
- [x] Implement logic to replace calculations with wrapper
- [x] Add example with cache_calculation on word_count

## Phase 6: Cache Operations (Real Implementation)
### Task 7.1: Cache Module Structure
- [x] Create lib/ash_memo/cache.ex with get_many/put_many/touch_many
- [x] Define return types for batch operations
- [x] Add single-key wrappers for backwards compatibility
- [x] Update example to demonstrate cache API

### Task 7.2: Cache Key Generation
- [x] Implement build_cache_key/3 in Cache module
- [x] Add example showing cache key format

### Task 7.3: Batch Get Implementation
- [x] Implement AshMemo.Cache.get_many/1 with single query
- [x] Update example to show batch lookups

### Task 7.4: Batch Put Implementation
- [x] Implement AshMemo.Cache.put_many/2 using bulk_create
- [x] Add example demonstrating bulk cache population

### Task 7.5: Wire Up CachedCalculation for Batch
- [x] Update calculate/3 to build all cache keys upfront
- [x] Implement batch lookup and separate hits/misses
- [x] Calculate all misses together via delegate
- [x] Batch insert all calculated results
- [x] Update example to show end-to-end caching

### Task 7.6: Batch Touch Implementation
- [x] Implement AshMemo.Cache.touch_many/1 using bulk_update
- [x] Add single async task for all cache hits
- [x] Add example showing access tracking

## Phase 7: Database Actions
### Task 8.1: Add Required Actions to CacheEntry
- [x] Add create :upsert action with upsert? true and upsert_identity :cache_key
- [x] Add update :touch action with atomic updates
- [x] Update example to use these actions

### Task 8.2: Migration Generation
- [x] Ensure migration creates table with cache_key as primary key
- [x] Ensure migration creates table with byte_size column
- [x] Add index on expires_at for TTL cleanup
- [x] Add composite index on (inserted_at, accessed_at) for FIFO/LRU
- [x] Add example migration file and instructions

## Phase 8: Configuration & Supervisor
### Task 4.1: Configuration Module
- [ ] Create lib/ash_memo/config.ex
- [ ] Update example config.exs to configure repo for AshMemo
- [ ] Add example configuration documentation

### Task 4.2: Basic Supervisor
- [ ] Create lib/ash_memo/supervisor.ex with empty children list
- [ ] Add support for max_entries and max_bytes options
- [ ] Update example application.ex to include AshMemo supervisor
- [ ] Add example configuration for limits

## Phase 9: Cleanup Process (Basic)
### Task 9.1: Create Cleaner GenServer
- [ ] Create lib/ash_memo/cleaner.ex
- [ ] Implement init/1 with timer scheduling
- [ ] Add max_entries and max_bytes to state (with defaults)
- [ ] Update example to show cleaner configuration

### Task 9.2: TTL Cleanup Implementation
- [ ] Implement handle_info(:ttl_cleanup, state)
- [ ] Add example with TTL configuration

### Task 9.3: Add Cleaner to Supervisor
- [ ] Add Cleaner to supervisor children
- [ ] Update example supervisor configuration

## Phase 10: Size-based Eviction (FIFO + Byte Limits)
### Task 10.1: Cache Statistics
- [ ] Implement aggregation query for count and total_bytes
- [ ] Add example showing cache statistics

### Task 10.2: Size Cleanup Implementation
- [ ] Implement handle_info(:size_cleanup, state) with dual limits
- [ ] Add example demonstrating FIFO eviction

### Task 10.3: Byte-aware Eviction
- [ ] Implement batch eviction based on byte size
- [ ] Add example with byte limit configuration

### Task 10.4: Configurable Limits
- [ ] Support max_entries = :unlimited behavior
- [ ] Support max_bytes with various values
- [ ] Add comprehensive example configuration

## Phase 11: Example Application Features
### Task 11.1: Basic Caching Example
- [ ] Update Post resource with cached word_count calculation
- [ ] Add script to demonstrate cache hits and misses
- [ ] Show TTL expiration behavior

### Task 11.2: Advanced Caching Examples
- [ ] Add expensive calculation example (e.g., sentiment analysis simulation)
- [ ] Add multiple cached calculations on same resource
- [ ] Demonstrate batch loading of posts with cached calculations

### Task 11.3: Performance Demonstration
- [ ] Add seed script to create many posts
- [ ] Add benchmark script showing N+1 query prevention
- [ ] Show memory usage with byte limits

### Task 11.4: Configuration Examples
- [ ] Add example with custom TTL per calculation
- [ ] Add example with different eviction strategies
- [ ] Add example with monitoring/metrics

## Phase 12: Polish & Documentation
### Task 12.1: Error Handling Examples
- [ ] Add example showing graceful degradation on cache errors
- [ ] Add example with serialization edge cases

### Task 12.2: Public API Examples
- [ ] Add convenience functions in example application
- [ ] Add examples of direct cache manipulation

### Task 12.3: README and Guides
- [ ] Update example README with comprehensive usage
- [ ] Add installation and setup instructions
- [ ] Add troubleshooting section
- [ ] Add performance tuning guide

## Definition of "Working Software"
- After Phase 1: Example project compiles with extension
- After Phase 2: Example uses DSL (no-op)
- After Phase 4: Example calculations work (no caching)
- After Phase 5: Example shows basic caching (transformer wires it up)
- After Phase 9: Example shows TTL cleanup
- After Phase 10: Example shows size limits
- After Phase 11: Example is feature-complete
- After Phase 12: Example is production-ready reference

## Critical Path
The minimum tasks to reach a working example:
1. Phase 1 → 2 → 3 → 4 → 5 → 6 → 7

This gives us an example with calculation caching and batch operations, which demonstrates the core functionality.

## Current Status
- Phases 1-3: ✓ Complete (Setup, DSL, Cache Entry)
- Phase 4: ✓ Complete (CachedCalculation implemented)
- Phase 5: ✓ Complete (Transformer integration)
- Phase 6: ✓ Complete (Cache operations implemented)
- Phase 7: ✓ Complete (Database actions and migration)
- **Phase 8: Next up** (Configuration & Supervisor)
- Phase 9: Cleanup Process (Basic TTL cleanup)
- Phase 10: Size-based Eviction (FIFO + Byte Limits)