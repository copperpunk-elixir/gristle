defmodule Actuator.Actuator do
  alias Actuator.Actuator, as: Actuator
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Actuator #{config[:name]}")
    # process_via_tuple = apply(config[:registry_module], config[:registry_function], [__MODULE__, config[:name]])
    {:ok, process_id} = GenServer.start_link(__MODULE__, config, name: config[:process_via_tuple])
    GenServer.cast(process_id, :start_pids)
  end

  # For a single actuator (aileron, rudder, etc)
  # pids = %{
  #   roll: [kp: 1.0, ki: 2.0, weight: 0.9],
  #   yaw: [kp: 0.2, ki: 0, weight: 0.1]
  # }
  # Can be accessed by  process_variable -> actuator -> pid(process_variable)

  @impl GenServer
  def init(config) do
    {:ok, %{
        registry_module: Keyword.get(config, :registry_module),
        registry_function: Keyword.get(config, :registry_function),
        name: Keyword.get(config, :name),
        pids: Keyword.get(config, :pids),
        weight: Keyword.get(config, :weight)
     }}
  end

  

  # @impl GenServer
  # def handle_cast({:update_pid, process_variable, process_var_error, dt}, state) do
    # process_via_tuple = apply(state.registry_module, config.registry_function, [Controller.Pid, {process_variable, state.name}])
  #   GenServer.cast(process_via_tuple, {:update, process_var_error, dt})
  #   {:noreply, state}
  # end
end
