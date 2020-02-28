defmodule Pc.System do
  def start_link(config) do
    Common.Utils.Comms.start_registry(:topic_registry)

    Supervisor.start_link(
      [
        Comms.ProcessRegistry,
        {Comms.Operator, config.comms},
        {CommandSorter.System, nil},
      ],
      strategy: :one_for_one
    )
  end
end
