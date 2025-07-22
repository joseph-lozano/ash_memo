defmodule AshMemo.InfoTest do
  use ExUnit.Case

  describe "cached_calculations/1" do
    test "returns empty list for resource without memo extension" do
      defmodule NoMemoResource do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
        end
      end

      assert AshMemo.Info.cached_calculations(NoMemoResource) == []
    end

    test "returns empty list for resource with memo extension but no calculations" do
      defmodule EmptyMemoResource do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshMemo.Resource]

        memo do
          # No cache calculations
        end

        attributes do
          uuid_primary_key :id
        end
      end

      assert AshMemo.Info.cached_calculations(EmptyMemoResource) == []
    end

    test "returns cache calculations with their configuration" do
      defmodule ConfiguredResource do
        use Ash.Resource,
          domain: nil,
          data_layer: Ash.DataLayer.Ets,
          extensions: [AshMemo.Resource]

        memo do
          cache_calculation :short_ttl do
            ttl :timer.seconds(30)
          end

          cache_calculation :long_ttl do
            ttl :timer.hours(24 * 7)
          end
        end

        attributes do
          uuid_primary_key :id
          attribute :value, :integer
        end
        
        calculations do
          calculate :short_ttl, :integer, expr(value * 5)
          calculate :long_ttl, :integer, expr(value * 10)
        end
      end

      cached_calcs = AshMemo.Info.cached_calculations(ConfiguredResource)
      
      assert length(cached_calcs) == 2
      
      short_ttl = Enum.find(cached_calcs, &(&1.name == :short_ttl))
      long_ttl = Enum.find(cached_calcs, &(&1.name == :long_ttl))
      
      assert short_ttl.ttl == :timer.seconds(30)
      assert long_ttl.ttl == :timer.hours(24 * 7)
    end
  end
end