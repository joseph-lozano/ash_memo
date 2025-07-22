defmodule AshMemo.Transformers.WrapCalculations do
  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    cached_calculations = Spark.Dsl.Transformer.get_entities(dsl_state, [:memo])

    dsl_state =
      Enum.reduce(cached_calculations, dsl_state, fn cached_calc, acc ->
        wrap_calculation(acc, cached_calc)
      end)

    {:ok, dsl_state}
  end

  defp wrap_calculation(dsl_state, cached_calc) do
    calc_name = cached_calc.name

    # Get the original calculation
    case Ash.Resource.Info.calculation(dsl_state, calc_name) do
      nil ->
        # If no calculation exists, we shouldn't add one
        # Just log a warning and continue
        IO.warn("Cached calculation #{calc_name} defined but no matching calculation found")
        dsl_state

      original_calc ->
        # Remove the original and add wrapped version
        opts = Map.merge(Map.from_struct(cached_calc), %{
          cache_key: calc_name,
          delegate: original_calc.calculation
        })
        
        dsl_state
        |> Spark.Dsl.Transformer.remove_entity([:calculations], &(&1.name == calc_name))
        |> Spark.Dsl.Transformer.add_entity(
          [:calculations],
          %{original_calc | calculation: {AshMemo.CachedCalculation, opts}}
        )
    end
  end
end

