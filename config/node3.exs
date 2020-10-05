use Mix.Config

# NOTICE the single quotes
config :riak_core,
  ring_state_dir: 'data/node3/data_riak_core',
  platform_data_dir: 'data/node3/data_riak_core',
  handoff_port: 8399
