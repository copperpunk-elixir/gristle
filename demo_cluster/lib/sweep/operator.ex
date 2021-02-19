defmodule Sweep.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, __MODULE__)
    Logger.debug("Start Sweep.Operator")
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  # @impl GenServer
  # def terminate(reason, state) do
  #   result = Circuits.UART.close(state.uart_ref)
  #   Logger.debug("Closing UART port with result: #{inspect(result)}")
  #   state
  # end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    {servo_output_classification, servo_output_time_validity_ms} = Configuration.MessageSorter.get_message_sorter_classification_time_validity_ms(__MODULE__, :servo_output)
    # min_pw = Keyword.fetch!(config, :min_pw)
    # max_pw = Keyword.fetch!(config, :max_pw)
    sweep_loop_interval_ms = Keyword.fetch!(config, :sweep_loop_interval_ms)
    # pw_intervals = round(full_sweep_interval_ms/(sweep_loop_interval_ms*2))
    # delta_pw = round((max_pw-min_pw)/pw_intervals)
    state = %{
      servos: config[:servos],
      # max_pw: max_pw,
      # delta_pw: delta_pw,
      servo_output_classification: servo_output_classification,
      servo_output_time_validity_ms: servo_output_time_validity_ms
    }
    Comms.System.start_operator(__MODULE__)
    Common.Utils.start_loop(self(), sweep_loop_interval_ms, :sweep_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:sweep_loop, state) do
    # new_pw = state.servo_output + state.delta_pw*state.pw_direction
    # {new_pw, direction} = cond do
    #   new_pw >= state.max_pw -> {state.max_pw, -1}
    #   new_pw <= state.min_pw -> {state.min_pw, 1}
    #   true -> {new_pw, state.pw_direction}
    # end
    servos = Enum.reduce(state.servos, %{}, fn ({index, servo}, acc) ->
      value = servo.value + servo.direction
      {value, direction} = cond do
        value >= servo.max_value -> {servo.max_value, -1}
        value <= servo.min_value -> {servo.min_value, 1}
        true -> {value, servo.direction}
      end
      # Logger.debug("#{index}/#{value}")
      Map.put(acc, index, %{servo | value: value, direction: direction})
    end)
    Comms.Operator.send_global_msg_to_group(__MODULE__, {{:global_msg_sorter, :servo_output}, state.servo_output_classification, state.servo_output_time_validity_ms, servos}, nil)
    {:noreply, %{state | servos: servos}}
  end
end
