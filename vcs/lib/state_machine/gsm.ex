defmodule StateMachine.Gsm do
  use GenStateMachine

  def start_link(config) do
    GenStateMachine.start_link(__MODULE__, {config.state, config.data})
  end

end
