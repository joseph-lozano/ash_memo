defmodule AshMemo.Repo do
  @moduledoc """
  Helper module for dynamically determining the repo to use for cache entries.
  """

  @doc """
  Gets the repo from a resource that must be using AshPostgres.DataLayer.
  Raises if the resource is not using AshPostgres.
  """
  def repo_from_resource(resource) do
    case Ash.Resource.Info.data_layer(resource) do
      AshPostgres.DataLayer ->
        AshPostgres.DataLayer.Info.repo(resource)

      other ->
        raise """
        AshMemo only supports resources using AshPostgres.DataLayer.

        Resource #{inspect(resource)} is using #{inspect(other)}.
        """
    end
  end
end
