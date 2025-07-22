defmodule AshMemo.ResourceTest do
  use ExUnit.Case

  describe "DSL" do
    test "can define a resource with memo extension" do
      defmodule BasicResource do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshMemo.Resource]

        memo do
          cache_calculation :test_calc do
            ttl :timer.minutes(5)
          end
        end

        attributes do
          uuid_primary_key :id
          attribute :value, :integer
        end
        
        calculations do
          calculate :test_calc, :integer, expr(value * 10)
        end
      end

      assert BasicResource
    end

    test "accepts multiple cache calculations" do
      defmodule MultiCacheResource do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshMemo.Resource]

        memo do
          cache_calculation :calc_one do
            ttl :timer.minutes(10)
          end

          cache_calculation :calc_two do
            ttl :timer.hours(1)
          end
        end

        attributes do
          uuid_primary_key :id
          attribute :value, :integer
        end
        
        calculations do
          calculate :calc_one, :integer, expr(value * 2)
          calculate :calc_two, :integer, expr(value * 3)
        end
      end

      assert MultiCacheResource
    end

    test "uses default TTL when not specified" do
      defmodule DefaultTTLResource do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshMemo.Resource]

        memo do
          cache_calculation :default_ttl_calc
        end

        attributes do
          uuid_primary_key :id
          attribute :value, :integer
        end
        
        calculations do
          calculate :default_ttl_calc, :integer, expr(value + 1)
        end
      end

      cached_calcs = AshMemo.Info.cached_calculations(DefaultTTLResource)
      [cache_calc] = cached_calcs
      
      # Default TTL is nil (no expiration)
      assert cache_calc.ttl == nil
    end

    test "accepts nil TTL explicitly" do
      defmodule NilTTLResource do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshMemo.Resource]

        memo do
          cache_calculation :nil_ttl_calc do
            ttl nil
          end
        end

        attributes do
          uuid_primary_key :id
          attribute :value, :integer
        end
        
        calculations do
          calculate :nil_ttl_calc, :integer, expr(value - 1)
        end
      end

      cached_calcs = AshMemo.Info.cached_calculations(NilTTLResource)
      [cache_calc] = cached_calcs
      
      assert cache_calc.ttl == nil
    end
  end
end