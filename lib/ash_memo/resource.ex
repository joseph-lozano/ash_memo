defmodule AshMemo.Resource do
  @moduledoc """
  The AshMemo extension for Ash resources.
  """

  @cache_calculation %Spark.Dsl.Entity{
    name: :cache_calculation,
    describe: """
    Configure caching for a specific calculation.
    """,
    args: [:name],
    target: AshMemo.CacheCalculation,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the calculation to cache"
      ],
      ttl: [
        type: {:or, [:integer, {:literal, nil}]},
        required: false,
        default: nil,
        doc:
          "Time-to-live for cached values in milliseconds. Use :timer functions like :timer.minutes(30). Defaults to nil (no expiration)."
      ]
    ]
  }

  @memo %Spark.Dsl.Section{
    name: :memo,
    describe: """
    Configure calculation caching for the resource.
    """,
    entities: [@cache_calculation]
  }

  use Spark.Dsl.Extension,
    sections: [@memo],
    transformers: [AshMemo.Transformers.WrapCalculations]
end
