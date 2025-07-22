import Config

config :example, Example.Repo,
  database: "ash_memo_example_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 10