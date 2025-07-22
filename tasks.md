# AshMemo v0 Implementation Tasks - TDD Approach

## Phase 1: Basic Project Setup & Compilation
### Task 1.1: Initialize Mix Project
- [ ] Create mix.exs with basic project structure
- [ ] Add minimal dependencies (ash, spark)
- [ ] Ensure `mix compile` works
- [ ] Create empty lib/ash_memo.ex module

### Task 1.2: Create Minimal DSL Extension
- [ ] Write failing test for basic DSL extension loading
- [ ] Create lib/ash_memo/resource.ex with empty Spark.Dsl.Extension
- [ ] Define memo section with no entities yet
- [ ] Test that resources can use the extension without errors

## Phase 2: DSL Structure (No Functionality)
### Task 2.1: Define cache_calculation Entity
- [ ] Write test for parsing cache_calculation DSL
- [ ] Add cache_calculation entity to memo section
- [ ] Define schema with :name (required) and :ttl (optional)
- [ ] Test DSL parsing with various configurations

### Task 2.2: Add Info Module for Introspection
- [ ] Write test for AshMemo.Info.cached_calculations/1
- [ ] Create lib/ash_memo/info.ex using Spark.Dsl.Fragment
- [ ] Implement cached_calculations/1 function
- [ ] Test retrieval of cached calculation configurations

## Phase 3: Cache Entry Resource (Storage Layer)
### Task 3.1: Create ErlangTerm Ecto Type
- [ ] Write tests for term serialization/deserialization
- [ ] Create lib/ash_memo/erlang_term.ex
- [ ] Add byte_size/1 function to calculate storage size
- [ ] Test with various Elixir data types
- [ ] Test error handling for corrupt data
- [ ] Test byte_size calculation accuracy

### Task 3.2: Define CacheEntry Resource
- [ ] Write test for CacheEntry resource compilation
- [ ] Create lib/ash_memo/cache_entry.ex with attributes
- [ ] Add cache_key as single primary key
- [ ] Add byte_size attribute to track cache entry size
- [ ] Test resource can be used in queries (no DB yet)

### Task 3.3: Create Domain
- [ ] Write test for domain compilation
- [ ] Create lib/ash_memo/domain.ex
- [ ] Add CacheEntry to domain resources
- [ ] Test domain can be used

## Phase 4: Configuration & Supervisor
### Task 4.1: Configuration Module
- [ ] Write test for missing repo configuration
- [ ] Create lib/ash_memo/config.ex
- [ ] Test error message when repo not configured
- [ ] Test successful repo retrieval when configured

### Task 4.2: Basic Supervisor
- [ ] Write test for supervisor start
- [ ] Create lib/ash_memo/supervisor.ex with empty children list
- [ ] Add support for max_entries and max_bytes options
- [ ] Test supervisor can be added to application
- [ ] Ensure no crashes on startup
- [ ] Test configuration options are passed to cleaner

## Phase 5: Calculation Wrapper (Always Miss)
### Task 5.1: Create CachedCalculation Module
- [ ] Write test for calculation initialization
- [ ] Create lib/ash_memo/cached_calculation.ex
- [ ] Implement init/1 to store options
- [ ] Test with various option configurations

### Task 5.2: Implement Calculate (Always Delegate)
- [ ] Write test that wrapped calculation returns same result
- [ ] Implement calculate/3 that always delegates
- [ ] Test with mock delegate calculation
- [ ] Verify records are processed correctly

### Task 5.3: Implement Load Delegation
- [ ] Write test for load/3 delegation
- [ ] Implement load/3 to delegate to wrapped calculation
- [ ] Test load behavior matches original

## Phase 6: Transformer Integration
### Task 6.1: Basic Transformer
- [ ] Write test for transformer application
- [ ] Create lib/ash_memo/transformers/wrap_calculations.ex
- [ ] Implement transform/1 to find cached calculations
- [ ] Test transformer is called during compilation

### Task 6.2: Calculation Replacement
- [ ] Write test for calculation wrapping
- [ ] Implement logic to replace calculations with wrapper
- [ ] Test original calculation is preserved as delegate
- [ ] Test wrapped calculation has correct options

## Phase 7: Cache Operations (Real Implementation)
### Task 7.1: Cache Module Structure
- [ ] Write tests for cache module API
- [ ] Create lib/ash_memo/cache.ex with get_many/put_many/touch_many stubs
- [ ] Define return types for batch operations
- [ ] Add single-key wrappers for backwards compatibility
- [ ] Test API contract

### Task 7.2: Cache Key Generation
- [ ] Write tests for cache key format
- [ ] Implement build_cache_key/3 in Cache module
- [ ] Test with various resource types and primary keys
- [ ] Ensure deterministic key generation
- [ ] Test format: "ModuleName:primary_key:calculation_name"

### Task 7.3: Batch Get Implementation
- [ ] Write test for batch cache lookups
- [ ] Implement AshMemo.Cache.get_many/1 with single query
- [ ] Test expired entries return :miss
- [ ] Test non-existent entries return :miss
- [ ] Test results returned in same order as input keys
- [ ] Test performance vs individual lookups

### Task 7.4: Batch Put Implementation
- [ ] Write test for batch storing values
- [ ] Implement AshMemo.Cache.put_many/2 using bulk_create
- [ ] Test TTL calculation (expires_at)
- [ ] Test byte_size is correctly stored for all entries
- [ ] Test bulk upsert behavior
- [ ] Test transaction atomicity

### Task 7.5: Wire Up CachedCalculation for Batch
- [ ] Write integration test for batch cache operations
- [ ] Update calculate/3 to build all cache keys upfront
- [ ] Implement batch lookup and separate hits/misses
- [ ] Calculate all misses together via delegate
- [ ] Batch insert all calculated results
- [ ] Test results assembled in correct order

### Task 7.6: Batch Touch Implementation
- [ ] Write test for batch touch operation
- [ ] Implement AshMemo.Cache.touch_many/1 using bulk_update
- [ ] Test accessed_at update for all entries
- [ ] Test access_count increment for all entries
- [ ] Add single async task for all cache hits
- [ ] Test performance vs individual touches

## Phase 8: Database Actions
### Task 8.1: Add Required Actions to CacheEntry
- [ ] Write test for upsert action
- [ ] Add create :upsert action with upsert? true and upsert_identity :cache_key
- [ ] Add update :touch action with atomic updates
- [ ] Test actions compile correctly
- [ ] Test bulk operations work with these actions

### Task 8.2: Migration Generation
- [ ] Write test for migration content
- [ ] Ensure migration creates table with cache_key as primary key
- [ ] Ensure migration creates table with byte_size column
- [ ] Add index on expires_at for TTL cleanup
- [ ] Add composite index on (inserted_at, accessed_at) for FIFO/LRU
- [ ] Test migration can be generated
- [ ] Document migration steps for users

## Phase 9: Cleanup Process (Basic)
### Task 9.1: Create Cleaner GenServer
- [ ] Write test for cleaner startup
- [ ] Create lib/ash_memo/cleaner.ex
- [ ] Implement init/1 with timer scheduling
- [ ] Add max_entries and max_bytes to state (with defaults)
- [ ] Test GenServer doesn't crash

### Task 9.2: TTL Cleanup Implementation
- [ ] Write test for expired entry deletion
- [ ] Implement handle_info(:ttl_cleanup, state)
- [ ] Test only expired entries are deleted
- [ ] Test cleanup is rescheduled

### Task 9.3: Add Cleaner to Supervisor
- [ ] Write test for supervisor children
- [ ] Add Cleaner to supervisor children
- [ ] Test cleaner starts with supervisor
- [ ] Test supervisor restarts cleaner on crash

## Phase 10: Size-based Eviction (FIFO + Byte Limits)
### Task 10.1: Cache Statistics
- [ ] Write test for get_cache_stats function
- [ ] Implement aggregation query for count and total_bytes
- [ ] Test with empty cache
- [ ] Test with populated cache

### Task 10.2: Size Cleanup Implementation
- [ ] Write test for entry count limit enforcement
- [ ] Write test for byte size limit enforcement
- [ ] Implement handle_info(:size_cleanup, state) with dual limits
- [ ] Test FIFO eviction (oldest inserted_at)
- [ ] Test eviction stops when under both limits

### Task 10.3: Byte-aware Eviction
- [ ] Write test for evict_until_bytes_freed function
- [ ] Implement batch eviction based on byte size
- [ ] Test eviction continues until byte limit met
- [ ] Test minimum entries are always evicted
- [ ] Test handles edge cases (empty batches, etc.)

### Task 10.4: Configurable Limits
- [ ] Write test for configuration options
- [ ] Test max_entries = :unlimited behavior
- [ ] Test max_bytes with various values
- [ ] Test default values (unlimited entries, 256MB bytes)
- [ ] Test supervisor passes options to cleaner

## Phase 11: Integration Testing
### Task 11.1: End-to-End Test Setup
- [ ] Create test resource with calculations
- [ ] Configure memo extension on test resource
- [ ] Set up test database and repo
- [ ] Write helper functions for test scenarios

### Task 11.2: Cache Hit/Miss Scenarios
- [ ] Test first call is cache miss and delegates
- [ ] Test second call is cache hit
- [ ] Test different records have different cache entries
- [ ] Test TTL expiration behavior

### Task 11.3: Batch Operation Tests
- [ ] Test loading calculations for multiple records uses single query
- [ ] Test mixed hits and misses are handled correctly
- [ ] Test delegation receives only miss records
- [ ] Test results maintain correct order
- [ ] Benchmark N+1 prevention (100 records = 1 query not 100)

### Task 11.4: Concurrent Access Tests
- [ ] Test multiple processes accessing same cache key
- [ ] Test race conditions in cache population
- [ ] Test touch operations don't block
- [ ] Verify data integrity under load

### Task 11.5: Byte Size Tracking Tests
- [ ] Test byte_size is accurately calculated for various data types
- [ ] Test cache respects byte size limits during normal operation
- [ ] Test eviction based on byte size works correctly
- [ ] Benchmark memory usage vs reported byte sizes

## Phase 12: Polish & Documentation
### Task 12.1: Error Handling
- [ ] Test graceful handling of serialization errors
- [ ] Test behavior when database is unavailable
- [ ] Add proper error messages
- [ ] Ensure calculations still work on cache errors

### Task 12.2: Public API
- [ ] Write tests for public API functions
- [ ] Implement convenience functions in lib/ash_memo.ex
- [ ] Add typespecs and documentation
- [ ] Test API ergonomics

### Task 12.3: README and Guides
- [ ] Create comprehensive README
- [ ] Add installation instructions
- [ ] Create usage examples
- [ ] Document configuration options

## Testing Strategy Notes
1. Each task should start with failing tests
2. Implementation should make tests pass with minimal code
3. Refactor only after tests are green
4. Use Mox for external dependencies when needed
5. Integration tests should use actual database when testing cache behavior
6. Unit tests should be isolated and fast

## Definition of "Working Software"
- After Phase 1: Project compiles
- After Phase 2: DSL can be used (no-op)
- After Phase 5: Calculations work (no caching)
- After Phase 7: Basic caching works
- After Phase 9: TTL cleanup works
- After Phase 10: Size limits enforced
- After Phase 12: Production ready

## Critical Path
The minimum tasks to reach a working (but incomplete) cache:
1. Phase 1 → 2 → 3 → 4 → 5 → 6 → 7.1-7.6 → 8.1

This gives us calculation caching with batch operations but without cleanup, which is functional but not production-ready.

## Key Changes from Original Design
- Single string cache key instead of composite key for efficient batch operations
- Batch operations (get_many, put_many, touch_many) to prevent N+1 queries
- All cache operations work on collections to optimize performance
- Simplified database schema without separate metadata fields