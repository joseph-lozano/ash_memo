defmodule AshMemo.CacheEntry do
  use Ash.Resource,
    domain: AshMemo.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("ash_memo_cache_entries")
    repo(&__MODULE__.repo/2)

    custom_indexes do
      index([:expires_at])
      index([:inserted_at, :accessed_at])
    end
  end

  def repo(_resource, _type) do
    # During migration generation, return a default repo
    # At runtime, this will be overridden by passing repo in options
    case Process.get(:ash_memo_migration_repo) do
      nil ->
        # Find all configured domains across all applications
        Application.loaded_applications()
        |> Enum.flat_map(fn {app, _, _} ->
          Application.get_env(app, :ash_domains, [])
        end)
        |> Enum.flat_map(&Ash.Domain.Info.resources/1)
        |> Enum.find_value(fn resource ->
          if Ash.Resource.Info.data_layer(resource) == AshPostgres.DataLayer do
            AshPostgres.DataLayer.Info.repo(resource)
          end
        end) || raise("No repo found for migration generation")

      repo ->
        repo
    end
  end

  attributes do
    attribute(:cache_key, :string, allow_nil?: false, primary_key?: true)
    attribute(:value, Ash.Type.Term)
    attribute(:byte_size, :integer, allow_nil?: false)
    attribute(:inserted_at, :utc_datetime_usec, default: &DateTime.utc_now/0)
    attribute(:expires_at, :utc_datetime_usec, allow_nil?: true)
    attribute(:accessed_at, :utc_datetime_usec, default: &DateTime.utc_now/0)
    attribute(:access_count, :integer, default: 1)
  end

  identities do
    identity(:cache_key, [:cache_key])
  end

  actions do
    defaults([:read, :destroy])

    create :upsert do
      accept([:cache_key, :value, :byte_size, :expires_at, :accessed_at, :access_count])
      upsert?(true)
      upsert_identity(:cache_key)
    end

    update :touch do
      change(set_attribute(:accessed_at, &DateTime.utc_now/0))
      change(increment(:access_count))
    end
  end
end
