defmodule Example.Posts.Post do
  use Ash.Resource,
    domain: Example.Posts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshMemo.Resource]

  postgres do
    table "posts"
    repo Example.Repo
  end

  memo do
    cache_calculation :word_count do
      ttl :timer.minutes(30)
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :content, :string
    create_timestamp :created_at
    update_timestamp :updated_at
  end

  calculations do
    calculate :word_count, :integer do
      calculation fn records, _opts ->
        Enum.map(records, fn record ->
          case record.content do
            nil -> 0
            content -> length(String.split(content, ~r/\s+/, trim: true))
          end
        end)
      end
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end
end