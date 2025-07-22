import Config

config :example, 
  ash_domains: [Example.Posts, AshMemo.Domain],
  ecto_repos: [Example.Repo]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"