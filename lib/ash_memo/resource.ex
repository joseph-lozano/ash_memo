defmodule AshMemo.Resource do
  @moduledoc """
  The AshMemo extension for Ash resources.
  """

  @memo %Spark.Dsl.Section{
    name: :memo,
    describe: """
    Configure calculation caching for the resource.
    """,
    entities: []
  }

  use Spark.Dsl.Extension,
    sections: [@memo],
    transformers: []
end