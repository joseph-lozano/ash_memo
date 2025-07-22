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
    case opts[:delegate] do
      {delegate_mod, delegate_opts} ->
        delegate_mod.load(query, delegate_opts, context)
      nil ->
        []
    end
  end

  @impl true
  def calculate([], _opts, _context), do: []
  
  def calculate(records, opts, context) do
    
    resource = List.first(records).__struct__
    calculation_name = opts[:cache_key]
    
    # Step 1: Build cache keys for all records
    cache_entries = Enum.map(records, fn record ->
      cache_key = AshMemo.Cache.build_cache_key(resource, record, calculation_name)
      {record, cache_key}
    end)
    
    cache_keys = Enum.map(cache_entries, &elem(&1, 1))
    
    # Step 2: Batch lookup all cache entries
    cached_values = AshMemo.Cache.get_many(cache_keys, resource)
    
    # Step 3: Separate hits and misses
    {hits, misses} = 
      cache_entries
      |> Enum.zip(cached_values)
      |> Enum.split_with(fn {_, value} -> value != :miss end)
    
    # Step 4: Handle cache hits (async touch)
    if hits != [] do
      hit_keys = Enum.map(hits, fn {{_, key}, _} -> key end)
      
      # In test mode or when async is disabled, run synchronously
      if Application.get_env(:ash, :disable_async?) do
        AshMemo.Cache.touch_many(hit_keys, resource)
      else
        Task.start(fn -> AshMemo.Cache.touch_many(hit_keys, resource) end)
      end
    end
    
    # Step 5: Calculate misses if any
    miss_results = if misses == [] do
      []
    else
      miss_records = Enum.map(misses, fn {{record, _}, _} -> record end)
      # Call the delegate calculation
      {delegate_mod, delegate_opts} = opts[:delegate]
      calculated_values = delegate_mod.calculate(miss_records, delegate_opts, context)
      
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
      
      AshMemo.Cache.put_many(cache_data, opts[:ttl], resource)
      
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