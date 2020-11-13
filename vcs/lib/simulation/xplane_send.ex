defmodule Simulation.XplaneSend do
  require Logger
  use Bitwise
  use GenServer

  @cmd_header <<68, 65, 84, 65, 0>>
  @zeros_1 <<0,0,0,0>>
  @zeros_3 <<0,0,0,0,0,0,0,0,0,0,0,0>>
  @zeros_4 <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>
  @zeros_5 <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>
  @zeros_7 <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>

  def start_link(config) do
    Logger.info("Start Simulation.XplaneSend GenServer")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    source_port = Keyword.fetch!(config, :source_port)
    {:ok, socket} = :gen_udp.open(source_port, [broadcast: false, active: false])
    state = %{
      socket: socket,
      dest_ip: Keyword.fetch!(config, :dest_ip),
      source_port: source_port,
      dest_port: Keyword.fetch!(config, :dest_port),
      pwm_channels: Keyword.fetch!(config, :pwm_channels),
      reversed_channels: Keyword.fetch!(config, :reversed_channels),
      commands: %{}
    }
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :pwm_input, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:update_actuators, actuators_and_outputs}, state) do
    cmds = Enum.reduce(actuators_and_outputs, %{}, fn ({actuator_name, {_actuator,output}}, acc) ->
      case actuator_name do
        :throttle -> Map.put(acc, actuator_name, output)
        :flaps -> Map.put(acc, actuator_name, output)
        name -> Map.put(acc, name, 2*(output - 0.5))
      end
    end)

    socket = state.socket
    dest_ip = state.dest_ip
    dest_port = state.dest_port
    send_ail_elev_rud_commands(cmds, socket, dest_ip, dest_port)
    send_throttle_command(cmds, socket, dest_ip, dest_port)
    send_flap_command(cmds, socket, dest_ip, dest_port)
    # Logger.debug("up act cmds: #{inspect(cmds)}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:pwm_input, scaled_values}, state) do
    pwm_channels = state.pwm_channels
    reversed_channels = state.reversed_channels
    # Logger.debug("pwm ch: #{inspect(pwm_channels)}")
    # Logger.debug("scaled: #{inspect(scaled_values)}")
    cmds = Enum.reduce(Enum.with_index(scaled_values), %{}, fn ({ch_value, index}, acc) ->
      actuator_name = Map.get(pwm_channels, index)
      ch_mult = if (Enum.member?(reversed_channels, actuator_name)), do: -1, else: 1
      case actuator_name do
        :throttle -> Map.put(acc, actuator_name, ch_value)
        :flaps -> Map.put(acc, actuator_name, ch_value)
        name -> Map.put(acc, name, ch_mult*2*(ch_value - 0.5))
      end
    end)
    # Logger.debug("cmds: #{inspect(cmds)}")
    socket = state.socket
    dest_ip = state.dest_ip
    dest_port = state.dest_port
    send_ail_elev_rud_commands(cmds, socket, dest_ip, dest_port)
    send_throttle_command(cmds, socket, dest_ip, dest_port)
    send_flap_command(cmds, socket, dest_ip, dest_port)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:send, message_type, message}, state) do
    func = "send_" <> Atom.to_string(message_type)
    |> String.to_atom()
    Logger.debug("function: #{func}")
    Logger.debug("message: #{inspect(message)}")
    apply(__MODULE__, func, [message, state.socket, state.dest_port])
    {:noreply, state}
  end

  @spec update_actuators(map()) :: atom()
  def update_actuators(actuators_and_outputs) do
    GenServer.cast(__MODULE__, {:update_actuators, actuators_and_outputs})
  end

  @spec send_ail_elev_rud_commands(map(), any(), tuple(), integer()) :: atom()
  def send_ail_elev_rud_commands(commands, socket, dest_ip, port) do
    buffer = @cmd_header <> <<11, 0, 0, 0>>
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(Map.get(commands, :elevator,-999),32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(Map.get(commands, :aileron,-999),32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(Map.get(commands, :rudder,-999),32))
    |> Kernel.<>(@zeros_5)
    # Logger.debug("buffer: #{buffer}")
    # Logger.debug("ail/elev/rud: #{Map.get(commands, :aileron)}/#{Map.get(commands, :elevator)}/#{Map.get(commands, :rudder)}")
    :gen_udp.send(socket, dest_ip, port, buffer)
  end

  @spec send_throttle_command(map(), any(), tuple(), integer()) :: atom()
  def send_throttle_command(commands, socket, dest_ip, port) do
    buffer = @cmd_header <> <<25, 0, 0, 0>>
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(Map.get(commands, :throttle,-999),32))
    |> Kernel.<>(@zeros_7)
    # |> Kernel.<>(<<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>)
    # Logger.debug("buffer: #{buffer}")
    # Logger.debug("thr: #{Map.get(commands, :throttle)}")
    :gen_udp.send(socket, dest_ip, port, buffer)
  end

  @spec send_flap_command(map(), any(), tuple(), integer()) :: atom()
  def send_flap_command(commands, socket, dest_ip, port) do
    # Logger.debug("flaps: #{Map.get(commands, :flaps)}")
    buffer = @cmd_header <> <<13, 0, 0, 0>>
    |> Kernel.<>(@zeros_3)
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(Map.get(commands, :flaps,-999),32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(-999,32))
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(-999,32))
    |> Kernel.<>(@zeros_1)
    |> Kernel.<>(Common.Utils.Math.uint_from_fp(-999,32))
    :gen_udp.send(socket, dest_ip, port, buffer)
  end

 #  @spec send_attitude(map(), any(), integer()) :: atom()
 #  def send_attitude(values, socket, port) do
 #    Logger.debug("send attitude: #{inspect(values)} to #{port}")
 #    buffer = @cmd_header <> <<17, 0, 0, 0>>
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.pitch,32))
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.roll,32))
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.yaw,32))
 #    |> Kernel.<>(@zeros_5)
 #    # |> Kernel.<>(<<0,0,0,0,0,0,0,0,0,0,0,0>>)
 #    :gen_udp.send(socket, {127,0,0,1}, port, buffer)
 #  end

 #  @spec send_bodyrate(map(), any(), integer()) :: atom()
 #  def send_bodyrate(values, socket, port) do
 #    Logger.debug("send bodyrate: #{inspect(values)}")
 #    buffer = @cmd_header <> <<16, 0, 0, 0>>
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.pitchrate,32))
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.rollrate,32))
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.yawrate,32))
 #    |> Kernel.<>(@zeros_5)
 #    # |> Kernel.<>(<<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>)
 #    :gen_udp.send(socket, {127,0,0,1}, port, buffer)
 #  end

 #  @spec send_accel(map(), any(), integer()) :: atom()
 #  def send_accel(values, socket, port) do
 #    Logger.debug("send accel: #{inspect(values)}")
 #    buffer = @cmd_header <> <<4, 0, 0, 0>>
 #    # |> Kernel.<>(<<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>)
 #    |> Kernel.<>(@zeros_4)
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.z,32))
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.x,32))
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.y,32))
 #    |> Kernel.<>(@zeros_1)
 #    :gen_udp.send(socket, {127,0,0,1}, port, buffer)
 #  end

 #  @spec send_position(map(), any(), integer()) :: atom()
 #  def send_position(values, socket, port) do
 #    Logger.debug("send position: #{inspect(values)}")
 #    buffer = @cmd_header <> <<20, 0, 0, 0>>
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(Common.Utils.Math.rad2deg(values.latitude),32))
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(Common.Utils.Math.rad2deg(values.longitude),32))
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.altitude,32))
 #    |> Kernel.<>(@zeros_5)
 #    # |> Kernel.<>(<<0,0,0,0,0,0,0,0,0,0,0,0>>)
 #    :gen_udp.send(socket, {127,0,0,1}, port, buffer)
 #  end

 # @spec send_velocity(map(), any(), integer()) :: atom()
 #  def send_velocity(values, socket, port) do
 #    Logger.debug("send velocity: #{inspect(values)}")
 #    buffer = @cmd_header <> <<21, 0, 0, 0>>
 #    # |> Kernel.<>(<<0,0,0,0,0,0,0,0,0,0,0,0>>)
 #    |> Kernel.<>(@zeros_5)
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(values.east,32))
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(-values.down,32))
 #    |> Kernel.<>(Common.Utils.Math.uint_from_fp(-values.north,32))
 #    :gen_udp.send(socket, {127,0,0,1}, port, buffer)
 #  end



 @spec send_message(atom(), map()) :: atom()
  def send_message(message_type, value) do
    GenServer.cast(__MODULE__, {:send, message_type, value})
  end

end
