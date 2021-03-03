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
    sweep_loop_interval_ms = Keyword.fetch!(config, :sweep_loop_interval_ms)
    state = %{
      servos: config[:servos],
      servo_output_classification: Keyword.fetch!(config, :servo_output_classification),
      servo_output_time_validity_ms: Keyword.fetch!(config, :servo_output_time_validity_ms),
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
    {servos_store, servos_send} = Enum.reduce(state.servos, {%{}, %{}}, fn ({index, servo}, {acc1, acc2}) ->
      value = servo.value + servo.direction
      {value, direction} = cond do
        value >= servo.max_value -> {servo.max_value, -1}
        value <= servo.min_value -> {servo.min_value, 1}
        true -> {value, servo.direction}
      end
      # Logger.debug("#{index}/#{value}")
      {Map.put(acc1, index, %{servo | value: value, direction: direction}), Map.put(acc2, index, %{value: value})}
    end)
    Comms.Operator.send_global_msg_to_group(__MODULE__, {{:global_msg_sorter, :servo_output}, state.servo_output_classification, state.servo_output_time_validity_ms, servos_send}, nil)
    {:noreply, %{state | servos: servos_store}}
  end
end
