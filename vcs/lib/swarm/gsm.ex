defmodule Swarm.Gsm do
  use GenStateMachine

  def start_link(config) do
    GenStateMachine.start_link(__MODULE__, {config.state, config.data})
  end

  def get_state_map() do
    states = [
      :disarmed,
      :ready,
      :rate,
      :attitude,
      :velocity_alt,
      :position
    ]
  end

end
