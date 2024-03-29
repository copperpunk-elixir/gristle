# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Enable the Nerves integration with Mix
# Application.start(:nerves_bootstrap)

config :demo_cluster, target: Mix.target()

# Customize non-Elixir parts of the firmware. See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :shoehorn,
  init: [:nerves_runtime, :vintage_net, :nerves_ssh],
  app: Mix.Project.config()[:app]

config :vintage_net,
  persistence: VintageNet.Persistence.Null

config :mdns_lite,
  host: :hostname

config :nerves, source_date_epoch: "1613405372"

# Use Ringlogger as the logger backend and remove :console.
# See https://hexdocs.pm/ring_logger/readme.html for more information on
# configuring ring_logger.

config :logger, backends: [RingLogger]

config :logger, RingLogger, max_size: 50_000

config :logger,
  level: :debug

config :ring_logger,
  format: "$time $metadata[$level] $levelpad$message\n",
  level: :debug,
  metadata: []

if Mix.target() != :host do
  import_config "target.exs"
end
