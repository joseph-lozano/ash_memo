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
        Spark.Dsl.Transformer.add_entity(
          dsl_state,
          [:calculations],
          %Ash.Resource.Calculation{
            name: calc_name,
            calculation: {AshMemo.CachedCalculation, original: nil, opts: cached_calc}
          }
        )

      original_calc ->
        # Remove the original and add wrapped version
        dsl_state
        |> Spark.Dsl.Transformer.remove_entity([:calculations], &(&1.name == calc_name))
        |> Spark.Dsl.Transformer.add_entity(
          [:calculations],
          %Ash.Resource.Calculation{
            original_calc
            | calculation:
                {AshMemo.CachedCalculation,
                 original: original_calc.calculation, opts: cached_calc}
          }
        )
    end
  end
end

