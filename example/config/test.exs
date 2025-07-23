import Config

config :example, Example.Repo,
  database: "ash_memo_example_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :example, ecto_repos: [Example.Repo]

config :ash, :disable_async?, true

# Set log level to warn to reduce noise during tests
config :logger, level: :warning
