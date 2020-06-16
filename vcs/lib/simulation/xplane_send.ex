defmodule Simulation.XplaneSend do
  require Logger
  use Bitwise
  use GenServer

  @cmd_header <<68, 65, 84, 65, 0>>

  def start_link(config) do
    Logger.debug("Start Simulation.XplaneSend")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(pid, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        socket: nil,
        port: config.port,
        vehicle_type: config.vehicle_type,
        commands: %{}
     }}
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.Operator.start_link(Configuration.Generic.get_operator_config(__MODULE__))
    {:ok, socket} = :gen_udp.open(state.port, [broadcast: false, active: false])
    {:noreply, %{state | socket: socket}}
  end

  @impl GenServer
  def handle_cast({:set_actuator_output, actuator_name, output}, state) do
    output =
      case actuator_name do
        :throttle -> output
        cmd -> 2*(output - 0.5)
      end
    # Logger.info("actuator_name/output: #{actuator_name}/#{output}")
    {:noreply, %{state | commands: Map.put(state.commands, actuator_name, output)}}
  end

  @impl GenServer
  def handle_cast(:update_actuators, state) do
    case state.vehicle_type do
      :Plane ->
        send_ail_elev_rud_commands(state.commands, state.socket)
        send_throttle_command(state.commands, state.socket)
    end
    # Logger.debug("cmds: #{inspect(state.commands)}")
    {:noreply, state}
  end


  @spec set_output_for_actuator(map(), atom(), float()) :: atom()
  def set_output_for_actuator(_actuator,actuator_name, output) do
    GenServer.cast(__MODULE__, {:set_actuator_output, actuator_name, output})
  end

  @spec update_actuators() :: atom()
  def update_actuators() do
    GenServer.cast(__MODULE__, :update_actuators)
  end

  @spec send_ail_elev_rud_commands(map(), any()) :: atom()
  def send_ail_elev_rud_commands(commands, socket) do
    buffer = @cmd_header <> <<11, 0, 0, 0>>
    buffer = buffer <> Common.Utils.Math.uint_from_fp(Map.get(commands, :elevator,-999),32)
    buffer = buffer <> Common.Utils.Math.uint_from_fp(Map.get(commands, :aileron,-999),32)
    buffer = buffer <> Common.Utils.Math.uint_from_fp(Map.get(commands, :rudder,-999),32)
    buffer = buffer <> <<"0,0,0,0,0,0,0,0,0,0,0,0">>
    # Logger.debug("buffer: #{buffer}")
    :gen_udp.send(socket, {127,0,0,1}, 49000,buffer)
  end

  @spec send_throttle_command(map(), any()) :: atom()
  def send_throttle_command(commands, socket) do
    buffer = @cmd_header <> <<25, 0, 0, 0>>
    buffer = buffer <> Common.Utils.Math.uint_from_fp(Map.get(commands, :throttle,-999),32)
    buffer = buffer <> <<"0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0">>
    # Logger.debug("buffer: #{buffer}")
    :gen_udp.send(socket, {127,0,0,1}, 49000,buffer)
  end
end
