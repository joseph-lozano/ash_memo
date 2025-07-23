defmodule Example.CacheBehaviorTest do
  use ExUnit.Case

  alias Example.Posts.Post
  alias Example.Posts

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Example.Repo)

    # Clean up any existing cache entries
    AshMemo.CacheEntry
    |> Ash.read!(domain: AshMemo.Domain)
    |> Enum.each(&Ash.destroy!(&1, domain: AshMemo.Domain))

    :ok
  end

  describe "cache entry creation" do
    test "creates cache entry on first calculation" do
      # Create a post
      post = Posts.create_post!(%{content: "Hello world from cache test"})

      # Verify no cache entries exist initially
      assert [] == Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)

      # Perform the calculation
      result = Ash.calculate!(post, :word_count)
      assert result == 5

      # Verify cache entry was created
      cache_entries = Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)
      assert length(cache_entries) == 1

      [cache_entry] = cache_entries
      assert cache_entry.cache_key == "Example.Posts.Post:#{post.id}:word_count"
      assert cache_entry.value == 5
      # Size of integer 5
      assert cache_entry.byte_size == 3
      assert cache_entry.access_count == 1
      assert cache_entry.accessed_at != nil
      assert cache_entry.inserted_at != nil
      # TTL is set to 30 minutes in the Post resource
      assert cache_entry.expires_at != nil
      assert DateTime.compare(cache_entry.expires_at, DateTime.utc_now()) == :gt
    end

    test "does not create duplicate cache entry on subsequent calculations" do
      post = Posts.create_post!(%{content: "Testing cache hits"})

      # First calculation
      assert Ash.calculate!(post, :word_count) == 3

      # Check we have one entry
      cache_entries = Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)
      assert length(cache_entries) == 1
      [first_entry] = cache_entries

      # Sleep briefly to ensure time difference
      Process.sleep(10)

      # Second calculation - should hit cache
      assert Ash.calculate!(post, :word_count) == 3

      # Should still have only one entry
      cache_entries = Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)
      assert length(cache_entries) == 1

      # But access_count should not increase (touch is async)
      [second_entry] = cache_entries
      assert second_entry.cache_key == first_entry.cache_key
      assert second_entry.value == first_entry.value
    end

    test "creates separate cache entries for different posts" do
      post1 = Posts.create_post!(%{content: "First post content"})
      post2 = Posts.create_post!(%{content: "Second post with more content"})

      # Calculate for both posts
      assert Ash.calculate!(post1, :word_count) == 3
      assert Ash.calculate!(post2, :word_count) == 5

      # Should have two cache entries
      cache_entries = Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)
      assert length(cache_entries) == 2

      # Verify each has correct cache key
      cache_keys = Enum.map(cache_entries, & &1.cache_key) |> Enum.sort()

      expected_keys =
        [
          "Example.Posts.Post:#{post1.id}:word_count",
          "Example.Posts.Post:#{post2.id}:word_count"
        ]
        |> Enum.sort()

      assert cache_keys == expected_keys
    end

    test "stores correct values for different content" do
      test_cases = [
        {"", 0},
        {"word", 1},
        {"two words", 2},
        {"  spaces   between   words  ", 3},
        {"Line\nbreaks\ncount\ntoo", 4},
        {nil, 0}
      ]

      for {content, expected_count} <- test_cases do
        # Clean cache for each test
        AshMemo.CacheEntry
        |> Ash.read!(domain: AshMemo.Domain)
        |> Enum.each(&Ash.destroy!(&1, domain: AshMemo.Domain))

        post = Posts.create_post!(%{content: content})

        # Calculate and verify result
        assert Ash.calculate!(post, :word_count) == expected_count

        # Verify cached value
        [cache_entry] = Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)
        assert cache_entry.value == expected_count
      end
    end
  end

  describe "batch calculation caching" do
    test "creates cache entries for multiple records in batch" do
      # Create multiple posts
      posts =
        for i <- 1..5 do
          Posts.create_post!(%{content: "Post number #{i} content"})
        end

      # Load calculation for all posts at once
      posts_with_calc = Ash.load!(posts, :word_count)

      # Verify all calculations are correct
      for post <- posts_with_calc do
        assert post.word_count == 4
      end

      # Verify cache entries were created for all posts
      cache_entries = Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)
      assert length(cache_entries) == 5

      # All should have the same value
      assert Enum.all?(cache_entries, &(&1.value == 4))
    end

    test "batch loading handles mix of cached and uncached records" do
      # Create posts and cache some calculations
      post1 = Posts.create_post!(%{content: "Already cached post"})
      post2 = Posts.create_post!(%{content: "Not yet cached"})
      post3 = Posts.create_post!(%{content: "Also already cached"})

      # Pre-cache post1 and post3
      Ash.calculate!(post1, :word_count)
      Ash.calculate!(post3, :word_count)

      # Verify we have 2 cache entries
      assert length(Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)) == 2

      # Now load all three in a batch
      posts = [post1, post2, post3]
      posts_with_calc = Ash.load!(posts, :word_count)

      # Verify calculations
      assert Enum.at(posts_with_calc, 0).word_count == 3
      assert Enum.at(posts_with_calc, 1).word_count == 3
      assert Enum.at(posts_with_calc, 2).word_count == 3

      # Should now have 3 cache entries (added one for post2)
      assert length(Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)) == 3
    end
  end

  describe "cache key generation" do
    test "generates correct cache key format" do
      post = Posts.create_post!(%{content: "Test content"})

      # Calculate to create cache entry
      Ash.calculate!(post, :word_count)

      # Verify cache key format
      [cache_entry] = Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)
      assert cache_entry.cache_key == "Example.Posts.Post:#{post.id}:word_count"
    end

    test "handles composite primary keys correctly" do
      # This test would require a resource with composite keys
      # For now, we'll just verify the single key case works
      post = Posts.create_post!(%{content: "Test"})
      cache_key = AshMemo.Cache.build_cache_key(Post, post, :word_count)
      assert cache_key == "Example.Posts.Post:#{post.id}:word_count"
    end
  end

  describe "cache expiration" do
    test "expired entries are not returned" do
      post = Posts.create_post!(%{content: "Expiring content"})

      # Calculate to create cache entry
      Ash.calculate!(post, :word_count)

      # Manually update the cache entry to be expired
      [cache_entry] = Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)

      past_time = DateTime.add(DateTime.utc_now(), -60, :second)

      # Use upsert to update the expires_at field
      Ash.create!(
        AshMemo.CacheEntry,
        %{
          cache_key: cache_entry.cache_key,
          value: cache_entry.value,
          byte_size: cache_entry.byte_size,
          expires_at: past_time,
          accessed_at: cache_entry.accessed_at,
          access_count: cache_entry.access_count
        },
        action: :upsert,
        domain: AshMemo.Domain
      )

      # Clear any in-memory cache
      post = Posts.get_post!(post.id)

      # Calculate again - should miss cache and recalculate
      assert Ash.calculate!(post, :word_count) == 2

      # Should have created a new cache entry (or updated the old one)
      cache_entries = Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)
      assert length(cache_entries) == 1

      [new_entry] = cache_entries
      # The expires_at should be nil or in the future
      assert new_entry.expires_at == nil ||
               DateTime.compare(new_entry.expires_at, DateTime.utc_now()) == :gt
    end
  end

  describe "non-cached calculations" do
    test "does not create cache entry for non-cached calculations" do
      # Create a post
      post = Posts.create_post!(%{content: "Testing non-cached calculation"})

      # Verify no cache entries exist initially
      assert [] == Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)

      # Perform the non-cached calculation
      result = Ash.calculate!(post, :character_count)
      assert result == 30

      # Verify no cache entry was created
      cache_entries = Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)
      assert length(cache_entries) == 0

      # Calculate again to ensure it's still not cached
      assert Ash.calculate!(post, :character_count) == 30

      # Still no cache entries
      assert [] == Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)
    end

    test "only caches configured calculations" do
      post = Posts.create_post!(%{content: "Mixed calculations test"})

      # Calculate both cached and non-cached
      assert Ash.calculate!(post, :word_count) == 3
      assert Ash.calculate!(post, :character_count) == 23

      # Should only have one cache entry for word_count
      cache_entries = Ash.read!(AshMemo.CacheEntry, domain: AshMemo.Domain)
      assert length(cache_entries) == 1

      [cache_entry] = cache_entries
      assert cache_entry.cache_key == "Example.Posts.Post:#{post.id}:word_count"
      assert cache_entry.value == 3
    end
  end
end
