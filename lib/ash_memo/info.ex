defmodule AshMemo.Info do
  @moduledoc """
  Introspection helpers for AshMemo
  """

  use Spark.Dsl.Fragment,
    of: Ash.Resource,
    data_layer: :domain

  @doc """
  Get the list of cached calculations defined on a resource.
  """
  @spec cached_calculations(Ash.Resource.t()) :: list(AshMemo.CacheCalculation.t())
  def cached_calculations(resource) do
    resource
    |> Spark.Dsl.Extension.get_entities([:memo])
    |> Enum.filter(&(&1.__struct__ == AshMemo.CacheCalculation))
  end
end