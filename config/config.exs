use Mix.Config

config :riak_core,
  handoff_port: 8099,
  handoff_ip: '127.0.0.1',
  schema_dirs: ['priv'],
  ring_creation_size: 16

config :rkv,
  redis_min_port: 6379,
  redis_max_port: 6379,
  kv_mod: Rkv.KV.DETS

import_config "#{Mix.env()}.exs"
