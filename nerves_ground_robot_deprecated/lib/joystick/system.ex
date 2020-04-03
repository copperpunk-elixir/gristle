defmodule Joystick.System do
  require Logger
  # There could potentially be more than one joystick attached to this node

  def start_link(config) do
    children = [
      Common.ProcessRegistry,
      {Comms.Operator, config.comms}
    ]
    children = Enum.reduce(Common.Utils.Enum.assert_list(config.joystick_interface_input),children, fn (joystick_interface_input, acc) ->
      id = Map.get(joystick_interface_input, :name, Joystick.InterfaceInput)
      acc ++ [Supervisor.child_spec({Joystick.InterfaceInput, joystick_interface_input}, id: id)]
    end)
    Logger.debug("children: #{inspect(children)}")
    Supervisor.start_link(
      children,
      strategy: :one_for_one
    )
  end
end
