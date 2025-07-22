defmodule AshMemo.CacheCalculationTest do
  use ExUnit.Case

  describe "struct creation" do
    test "creates a cache calculation struct with required fields" do
      cache_calc = %AshMemo.CacheCalculation{
        name: :test_calculation,
        ttl: :timer.minutes(30)
      }

      assert cache_calc.name == :test_calculation
      assert cache_calc.ttl == :timer.minutes(30)
    end
  end
end