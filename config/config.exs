use Mix.Config

config :riak_core,
  handoff_port: 8099,
  handoff_ip: '127.0.0.1',
  schema_dirs: ['priv'],
  ring_creation_size: 64

import_config "#{Mix.env()}.exs"
