defmodule AshMemo.InfoTest do
  use ExUnit.Case
  
  describe "cached_calculations/1" do
    test "returns cached calculations for a resource" do
      cached_calcs = AshMemo.Info.cached_calculations(Example.Posts.Post)
      
      assert length(cached_calcs) == 1
      
      [cache_calc] = cached_calcs
      assert cache_calc.name == :word_count
      assert cache_calc.ttl == :timer.minutes(30)
    end
    
    test "introspects multiple cached calculations" do
      defmodule MultiCacheResource do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshMemo.Resource]
        
        memo do
          cache_calculation :calculation_one do
            ttl :timer.minutes(10)
          end
          
          cache_calculation :calculation_two do
            ttl :timer.hours(1)
          end
        end
        
        attributes do
          uuid_primary_key :id
        end
      end
      
      cached_calcs = AshMemo.Info.cached_calculations(MultiCacheResource)
      
      assert length(cached_calcs) == 2
      assert Enum.find(cached_calcs, &(&1.name == :calculation_one))
      assert Enum.find(cached_calcs, &(&1.name == :calculation_two))
    end
  end
end