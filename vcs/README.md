# Vcs (Vehicle Control System)

This is the new vehicle control system, based on decentralized control and maximum inter-node oversight.

Although this is a Nerves project, it can be run on any computer with Elixir install.

To run unit tests:
    `mix test test/` from root project folder

The diagram of the architecture is below.  
It can be viewed as an [.html](https://github.com/some-assembly-required/gristle/blob/master/resources/diagrams/images/VCS_v0.2.html) file, although you cannot preview it in Github.  
The raw Draw.io file is available in the [resources](https://github.com/some-assembly-required/gristle/tree/master/resources/diagrams) folder.  
![diagram](https://github.com/some-assembly-required/gristle/blob/master/resources/diagrams/images/VCS_v0.2.png)

## Targets

Nerves applications produce images for hardware targets based on the
`MIX_TARGET` environment variable. If `MIX_TARGET` is unset, `mix` builds an
image that runs on the host (e.g., your laptop). This is useful for executing
logic tests, running utilities, and debugging. Other targets are represented by
a short name like `rpi3` that maps to a Nerves system image for that platform.
All of this logic is in the generated `mix.exs` and may be customized. For more
information about targets see:

https://hexdocs.pm/nerves/targets.html#content

## Getting Started

To start your Nerves app:
  * `export MIX_TARGET=my_target` or prefix every command with
    `MIX_TARGET=my_target`. For example, `MIX_TARGET=rpi3`
  * Install dependencies with `mix deps.get`
  * Create firmware with `mix firmware`
  * Burn to an SD card with `mix firmware.burn`