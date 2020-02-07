defmodule Joystick.System do
  require Logger
  # There could potentially be more than one joystick attached to this node

  def start_link(config) do
    children = [
      Common.ProcessRegistry,
      {Comms.Operator, config.comms}
    ]
    children = Enum.reduce(Common.Utils.Enum.assert_list(config.joystick_controller),children, fn (joystick_controller, acc) ->
      id = Map.get(joystick_controller, :name, Joystick.Controller)
      acc ++ [Supervisor.child_spec({Joystick.Controller, joystick_controller}, id: id)]
    end)
    Logger.debug("children: #{inspect(children)}")
    Supervisor.start_link(
      children,
      strategy: :one_for_one
    )
  end
end
