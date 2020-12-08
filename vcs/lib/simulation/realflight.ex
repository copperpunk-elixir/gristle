defmodule Simulation.Realflight do
  require Logger
  use Bitwise
  use GenServer

  @deg2rad 0.017453293
  @pi_2 1.57079633
  @ft2m 0.3048
  @knots2mps 0.51444444
  @rad2deg 57.295779513
  @default_latitude 41.769201
  @default_longitude -122.506394
  @default_servo [0.5, 0.5, 0, 0.5, 0.5, 0, 0.5, 0, 0.5, 0.5, 0.5, 0.5]
  @rf_stick_mult 1.07

  def start() do
    start_link([host_ip: "192.168.7.136", sim_loop_interval_ms: 1000000])
  end

  def start_link(config) do
    Logger.info("Start Simulation.Realflight GenServer")
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
    Comms.System.start_operator(__MODULE__)
    url = Keyword.fetch!(config, :host_ip) <>(":18083")
    Logger.debug("url: #{url}")
    state = %{
      url: url,
      attitude: %{},
      bodyrate: %{},
      position: %{},
      velocity: %{},
      position_origin: Common.Utils.LatLonAlt.new_deg(@default_latitude, @default_longitude),
      agl: 0,
      airspeed: 0,
      rcin: @default_servo,
      servo_out: @default_servo
    }
    restore_controller(url)
    inject_controller_interface(url)
    Common.Utils.start_loop(self(), config[:sim_loop_interval_ms], :exchange_data_loop)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:post, msg, params}, state) do
    Logger.debug("post: #{msg}")
    state =
      case msg do
        :reset ->
          reset_aircraft(state.url)
          state
        :restore ->
          restore_controller(state.url)
          state
        :inject ->
          inject_controller_interface(state.url)
          state
        :exchange -> exchange_data(state, params)
      end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:update_actuators, output_map}, state) do
    servo_out = if Enum.empty?(output_map) do
      state.servo_out
    else
      # Logger.debug("output map: #{inspect(output_map)}")
      {_, aileron} = Map.get(output_map, :aileron, {nil, 0.5})
      {_, elevator} = Map.get(output_map, :elevator, {nil, 0.5})
      {_, throttle} = Map.get(output_map, :throttle, {nil, 0.0})
      {_, rudder} = Map.get(output_map, :rudder, {nil, 0.5})
      {_, flaps} = Map.get(output_map, :flaps, {nil, 0.0})

      [aileron, 1-elevator, throttle, rudder, 0, flaps,0,0,0,0,0,0]
    end
    # Logger.info("servo_out: #{inspect(servo_out)}")
    {:noreply, %{state | servo_out: servo_out}}
  end

  # @spec get_servo_value_from_actuator_map(map(), atom(), float()) :: float()
  # def get_servo_value_from_actuator_map(actuator_map, key, default_value) do
  #   case Map.get(output_map, key)
  # end

  @impl GenServer
  def handle_info(:exchange_data_loop, state) do
    state = exchange_data(state, state.servo_out)
    # state = exchange_data(state, state.rcin)
    publish_perfect_simulation_data(state)
    # Remove channel 5, add fake channel 7, so that flaps and gear will be in the right place
    # I apologize for the hack, but this keeps me from having to change the Command configuration.

    # Logger.debug("#{inspect(state.rcin)}")
    {rc_1_4, rc_5_12} = Enum.split(state.rcin, 4)
    {rc_5_7, rc_8_12} = Enum.split(rc_5_12, 3)
    rc_5_7 = Enum.drop(rc_5_7, 1) ++ [0.5]
    rcin = rc_1_4 ++ rc_5_7 ++ rc_8_12
    rx_output = Enum.map(rcin, fn x ->
      (x - 0.5)*2
    end )
    Comms.Operator.send_local_msg_to_group(__MODULE__, {:rx_output, rx_output, false}, :rx_output, self())
    {:noreply, state}
  end

  def fix_rx(x) do
    (x - 0.5)*@rf_stick_mult + 0.5
  end

  @spec update_actuators(map()) :: atom()
  def update_actuators(actuators_and_outputs) do
    GenServer.cast(__MODULE__, {:update_actuators, actuators_and_outputs})
  end

  @spec publish_perfect_simulation_data(map()) ::atom()
  def publish_perfect_simulation_data(state) do
    unless Enum.empty?(state.bodyrate) or Enum.empty?(state.attitude) or Enum.empty?(state.velocity) or Enum.empty?(state.position) do
      Peripherals.Uart.Estimation.VnIns.Operator.publish_vn_message(state.bodyrate, state.attitude, state.velocity, state.position)
    end
    # Comms.Operator.send_local_msg_to_group(__MODULE__, {{:pv_calculated, :airspeed}, state.airspeed}, {:pv_calculated, :airspeed}, self())
    if !Enum.empty?(state.attitude) and (:rand.uniform(5) == 1) do
      range_meas =state.agl/(:math.cos(state.attitude.roll)*:math.cos(state.attitude.pitch))
      range_meas = if (range_meas < 0), do: 0, else: range_meas
      Peripherals.Uart.Estimation.TerarangerEvo.Operator.publish_range(range_meas)
    end
  end

  @spec reset_aircraft(binary()) :: atom()
  def reset_aircraft(url) do
    body = "<?xml version='1.0' encoding='UTF-8'?>
    <soap:Envelope xmlns:soap='http://schemas.xmlsoap.org/soap/envelope/' xmlns:xsd='http://www.w3.org/2001/XMLSchema' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>
    <soap:Body>
    <ResetAircraft><a>1</a><b>2</b></ResetAircraft>
    </soap:Body>
    </soap:Envelope>"
    Logger.debug("body: #{inspect(body)}")
    Logger.debug("reset")
    response = post_poison(url, body)
    Logger.debug("reset response: #{response}")
    # Logger.debug("#{inspect(Soap.Response.parse(response.body))}")
  end

  @spec restore_controller(binary()) :: atom()
  def restore_controller(url) do
    body = "<?xml version='1.0' encoding='UTF-8'?>
    <soap:Envelope xmlns:soap='http://schemas.xmlsoap.org/soap/envelope/' xmlns:xsd='http://www.w3.org/2001/XMLSchema' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>
    <soap:Body>
    <RestoreOriginalControllerDevice><a>1</a><b>2</b></RestoreOriginalControllerDevice>
    </soap:Body>
    </soap:Envelope>"
    Logger.debug("restore")
    post_poison(url, body)
  end

  @spec inject_controller_interface(binary()) :: atom()
  def inject_controller_interface(url) do
    body = "<?xml version='1.0' encoding='UTF-8'?>
    <soap:Envelope xmlns:soap='http://schemas.xmlsoap.org/soap/envelope/' xmlns:xsd='http://www.w3.org/2001/XMLSchema' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>
    <soap:Body>
    <InjectUAVControllerInterface><a>1</a><b>2</b></InjectUAVControllerInterface>
    </soap:Body>
    </soap:Envelope>"
    post_poison(url, body)
  end

  @spec exchange_data(map(), list()) :: atom()
  def exchange_data(state, servo_output) do
    # start_time = :os.system_time(:microsecond)
    # Logger.debug("start: #{start_time}")
    body_header = "<?xml version='1.0' encoding='UTF-8'?>
    <soap:Envelope xmlns:soap='http://schemas.xmlsoap.org/soap/envelope/' xmlns:xsd='http://www.w3.org/2001/XMLSchema' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>
    <soap:Body>
    <ExchangeData>
    <pControlInputs>
    <m-selectedChannels>4095</m-selectedChannels>
    <m-channelValues-0to1>"
    body_footer = "</m-channelValues-0to1>
                                 </pControlInputs>
                                 </ExchangeData>
                                 </soap:Body>
                                 </soap:Envelope>"
    servo_str = Enum.reduce(servo_output, "", fn (value, acc) ->
      acc <> "<item>#{Common.Utils.eftb(value, 4)}</item>"
    end)
    body = body_header <> servo_str <> body_footer
    # Logger.debug("body: #{inspect(body)}")
    response = post_poison(state.url, body)
    xml_map =
      case SAXMap.from_string(response) do
        {:ok, xml} -> xml
        _other -> %{}
      end
    return_data = get_in(xml_map, return_data_path())
    # Logger.info("#{inspect(return_data)}")
    if is_nil(return_data) do
      state
    else
      aircraft_state = extract_from_path(return_data, aircraft_state_path())
      rcin_values = extract_from_path(return_data, rcin_path())
      position = extract_position(aircraft_state, state.position_origin)
      # Logger.debug("position: #{Common.Utils.LatLonAlt.to_string(position)}")
      velocity = extract_velocity(aircraft_state)
      # Logger.debug("velocity: #{inspect(velocity)}")
      attitude = extract_attitude(aircraft_state)
      # Logger.debug("attitude: #{inspect(Common.Utils.map_rad2deg(attitude))}")
      bodyrate = extract_bodyrate(aircraft_state)
      # Logger.debug("bodyrate: #{inspect(Common.Utils.map_rad2deg(bodyrate))}")
      agl = extract_agl(aircraft_state)
      # Logger.debug("agl: #{agl}")
      airspeed = extract_airspeed(aircraft_state)
      # Logger.debug("airspeed: #{airspeed}")
      rcin = extract_rcin(rcin_values)
      # Logger.debug("rcin: #{inspect(rcin)}")
      # end_time = :os.system_time(:microsecond)
      # Logger.debug("dt: #{Common.Utils.eftb((end_time-start_time)*0.001,1)}")
      %{state | bodyrate: bodyrate, attitude: attitude, position: position, velocity: velocity, agl: agl, airspeed: airspeed, rcin: rcin}
    end
  end


  @spec reset_aircraft() :: atom()
  def reset_aircraft() do
    GenServer.cast(__MODULE__, {:post, :reset, nil})
  end

  @spec restore_controller() :: atom()
  def restore_controller() do
    Logger.info("here")
    GenServer.cast(__MODULE__, {:post, :restore, nil})
  end

  @spec inject_controller_interface() :: atom()
  def inject_controller_interface() do
    GenServer.cast(__MODULE__, {:post, :inject, nil})
  end

  @spec set_throttle(float()) :: atom()
  def set_throttle(throttle) do
    servos = Enum.reduce(0..11, [], fn (x, acc) ->
      if x == 2, do: [throttle] ++ acc, else: [0.5] ++ acc
    end)
    |> Enum.reverse()
    GenServer.cast(__MODULE__, {:post, :exchange, servos})
  end

  @spec post_poison(binary(), binary(), integer()) :: binary()
  def post_poison(url, body, timeout \\ 10) do
    case HTTPoison.post(url, body, [], [timeout: timeout]) do
      {:ok, response} -> response.body
      {:error, error} ->
        Logger.warn("HTTPoison error: #{inspect(error)}")
        ""
    end
  end

  @spec return_data_path() :: list()
  def return_data_path() do
    ["SOAP-ENV:Envelope", "SOAP-ENV:Body", "ReturnData"]
  end

  @spec aircraft_state_path() :: list()
  def aircraft_state_path() do
    ["m-aircraftState"]
  end

  @spec rcin_path() :: list()
  def rcin_path() do
    ["m-previousInputsState", "m-channelValues-0to1", "item"]
  end

  @spec extract_from_path(map(), list()) :: map()
  def extract_from_path(data, path) do
    if (Enum.empty?(path)) do
      data
    else
      {[next_path], remaining_path} = Enum.split(path, 1)
      # Logger.debug("next: #{next_path}")
      # Logger.debug("remaining: #{inspect(remaining_path)}")
      data = Map.get(data, next_path, %{})
      extract_from_path(data, remaining_path)
    end
  end

  @spec extract_position(map(), struct()) :: map()
  def extract_position(aircraft_state, origin) do
    lookup_keys = ["m-aircraftPositionX-MTR", "m-aircraftPositionY-MTR", "m-altitudeASL-MTR"]
    store_keys = [:y, :x, :z]
    pos_data = extract_all_or_nothing(aircraft_state, Enum.zip(lookup_keys, store_keys))
    if Enum.empty?(pos_data) do
      %{}
    else
      # Logger.debug("#{inspect(pos_data)}")
      pos = convert_all_to_float(pos_data)
      Map.from_struct(Common.Utils.Location.lla_from_point(origin, pos.x, pos.y))
      |> Map.put(:altitude, pos.z)
    end
  end

  @spec extract_velocity(map()) :: map()
  def extract_velocity(aircraft_state) do
    lookup_keys = ["m-velocityWorldU-MPS", "m-velocityWorldV-MPS", "m-velocityWorldW-MPS"]
    store_keys = [:north, :east, :down]
    vel_data = extract_all_or_nothing(aircraft_state, Enum.zip(lookup_keys, store_keys))
    if Enum.empty?(vel_data) do
      %{}
    else
      convert_all_to_float(vel_data)
    end
  end

  @spec extract_quat(map()) :: map()
  def extract_quat(aircraft_state) do
    lookup_keys = ["m-orientationQuaternion-W", "m-orientationQuaternion-X", "m-orientationQuaternion-Y",  "m-orientationQuaternion-Z"]
    store_keys = [:w, :y, :x, :z]
    quat_data = extract_all_or_nothing(aircraft_state, Enum.zip(lookup_keys, store_keys))
    if Enum.empty?(quat_data) do
      %{}
    else
      convert_all_to_float(quat_data)
    end
  end

  @spec extract_bodyrate(map()) :: map()
  def extract_bodyrate(aircraft_state) do
    lookup_keys = ["m-rollRate-DEGpSEC", "m-pitchRate-DEGpSEC", "m-yawRate-DEGpSEC"]
    store_keys = [:rollrate, :pitchrate, :yawrate]
    rate_data = extract_all_or_nothing(aircraft_state, Enum.zip(lookup_keys, store_keys))
    if Enum.empty?(rate_data) do
      %{}
    else
      convert_all_to_float(rate_data, :math.pi()/180)
    end
  end

  @spec extract_agl(map()) :: float()
  def extract_agl(aircraft_state) do
    agl = Map.get(aircraft_state, "m-altitudeAGL-MTR")
    if is_nil(agl), do: nil, else: String.to_float(agl)
  end

  @spec extract_airspeed(map()) :: float()
  def extract_airspeed(aircraft_state) do
    airspeed = Map.get(aircraft_state, "m-airspeed-MPS")
    if is_nil(airspeed) do
      nil
    else
      {x_float, _rem} = Float.parse(airspeed)
      x_float
    end
  end

  @spec extract_attitude(map()) :: map()
  def extract_attitude(aircraft_state) do
    quat = extract_quat(aircraft_state)
    # Logger.debug("quat: #{inspect(quat)}")
    Common.Utils.Motion.quaternion_to_euler(quat.w, quat.x, quat.y, -quat.z)
  end

  @spec extract_ria(map()) :: map()
  def extract_ria(aircraft_state) do
    lookup_keys = ["m-roll-DEG", "m-inclination-DEG", "m-azimuth-DEG"]
    store_keys = [:roll, :pitch, :yaw]
    rate_data = extract_all_or_nothing(aircraft_state, Enum.zip(lookup_keys, store_keys))
    if Enum.empty?(rate_data) do
      %{}
    else
      convert_all_to_float(rate_data, :math.pi()/180)
    end
  end

  @spec extract_rcin(map()) :: list()
  def extract_rcin(input_state) do
    Enum.map(input_state, fn input ->
      {input_float, _} = Float.parse(input)
      # (input_float - 0.5) * 2.0
      input_float
    end)
  end

  @spec extract_all_or_nothing(map(), list(), map()) :: map()
  def extract_all_or_nothing(data, lookup_store_tuples, accumulator \\ %{}) do
    if Enum.empty?(lookup_store_tuples) do
      accumulator
    else
      {[{lookup_key, store_key}], lookup_store_tuples} = Enum.split(lookup_store_tuples, 1)
      value = Map.get(data, lookup_key)
      if is_nil(value) do
        Logger.debug("missing value: exit")
        %{}
      else
        # Logger.debug("good value, continue: #{inspect(lookup_store_tuples)}")
        extract_all_or_nothing(data, lookup_store_tuples, Map.put(accumulator, store_key, value))
      end
    end
  end

  @spec convert_all_to_float(map(), number()) :: map()
  def convert_all_to_float(string_values, mult \\ 1) do
    Enum.reduce(string_values, %{}, fn ({key, value}, acc) ->
      {x_float, _rem} = Float.parse(value)
      Map.put(acc, key, x_float*mult)
    end)
  end

  def get_test_xml() do
"<?xml version=\"1.0\" encoding=\"UTF-8\"?><SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><SOAP-ENV:Body><ReturnData><m-previousInputsState><m-selectedChannels>-1</m-selectedChannels><m-channelValues-0to1 xsi:type=\"SOAP-ENC:Array\" SOAP-ENC:arrayType=\"xsd:double[12]\"><item>0.5</item><item>0.5</item><item>0</item><item>0.5</item><item>0.5</item><item>0</item><item>0</item><item>0</item><item>0</item><item>0.5</item><item>0.5</item><item>0.5</item></m-channelValues-0to1></m-previousInputsState><m-aircraftState><m-currentPhysicsTime-SEC>708.01227736799046</m-currentPhysicsTime-SEC><m-currentPhysicsSpeedMultiplier>1</m-currentPhysicsSpeedMultiplier><m-airspeed-MPS>0.0021798373622661884</m-airspeed-MPS><m-altitudeASL-MTR>0.14938228996838809</m-altitudeASL-MTR><m-altitudeAGL-MTR>0.14938228996838809</m-altitudeAGL-MTR><m-groundspeed-MPS>0.00014266304921026299</m-groundspeed-MPS><m-pitchRate-DEGpSEC>-0.49789883184564587</m-pitchRate-DEGpSEC><m-rollRate-DEGpSEC>0.77367656234457627</m-rollRate-DEGpSEC><m-yawRate-DEGpSEC>0.034366898669809132</m-yawRate-DEGpSEC><m-azimuth-DEG>71.528457641601562</m-azimuth-DEG><m-inclination-DEG>0.25129407644271851</m-inclination-DEG><m-roll-DEG>0.13396531343460083</m-roll-DEG><m-orientationQuaternion-X>0.0010961623629555106</m-orientationQuaternion-X><m-orientationQuaternion-Y>0.0022302858997136354</m-orientationQuaternion-Y><m-orientationQuaternion-Z>0.58445149660110474</m-orientationQuaternion-Z><m-orientationQuaternion-W>0.81142467260360718</m-orientationQuaternion-W><m-aircraftPositionX-MTR>34510.3515625</m-aircraftPositionX-MTR><m-aircraftPositionY-MTR>46654.50390625</m-aircraftPositionY-MTR><m-velocityWorldU-MPS>-0.00012938663712702692</m-velocityWorldU-MPS><m-velocityWorldV-MPS>6.0098616813775152E-005</m-velocityWorldV-MPS><m-velocityWorldW-MPS>0.0021751639433205128</m-velocityWorldW-MPS><m-velocityBodyU-MPS>-0.00010753551032394171</m-velocityBodyU-MPS><m-velocityBodyV-MPS>-9.8594442533794791E-005</m-velocityBodyV-MPS><m-velocityBodyW-MPS>0.0021749495062977076</m-velocityBodyW-MPS><m-accelerationWorldAX-MPS2>0.00080946780508384109</m-accelerationWorldAX-MPS2><m-accelerationWorldAY-MPS2>0.0046665812842547894</m-accelerationWorldAY-MPS2><m-accelerationWorldAZ-MPS2>8.8538541793823242</m-accelerationWorldAZ-MPS2><m-accelerationBodyAX-MPS2>0.018117452040314674</m-accelerationBodyAX-MPS2><m-accelerationBodyAY-MPS2>-0.060176290571689606</m-accelerationBodyAY-MPS2><m-accelerationBodyAZ-MPS2>-9.4150829315185547</m-accelerationBodyAZ-MPS2><m-windX-MPS>0</m-windX-MPS><m-windY-MPS>0</m-windY-MPS><m-windZ-MPS>0</m-windZ-MPS><m-propRPM>2075.375</m-propRPM><m-heliMainRotorRPM>-1</m-heliMainRotorRPM><m-batteryVoltage-VOLTS>12.519639647435969</m-batteryVoltage-VOLTS><m-batteryCurrentDraw-AMPS>0.44040951132774353</m-batteryCurrentDraw-AMPS><m-batteryRemainingCapacity-MAH>2473.21337890625</m-batteryRemainingCapacity-MAH><m-fuelRemaining-OZ>-1</m-fuelRemaining-OZ><m-isLocked>false</m-isLocked><m-hasLostComponents>false</m-hasLostComponents><m-anEngineIsRunning>true</m-anEngineIsRunning><m-isTouchingGround>true</m-isTouchingGround><m-flightAxisControllerIsActive>true</m-flightAxisControllerIsActive><m-currentAircraftStatus>CAS-WAITINGTOLAUNCH</m-currentAircraftStatus></m-aircraftState><m-notifications><m-resetButtonHasBeenPressed>false</m-resetButtonHasBeenPressed></m-notifications></ReturnData></SOAP-ENV:Body></SOAP-ENV:Envelope>"
  end

  def get_deficient_xml() do
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><SOAP-ENV:Body><ReturnData><m-previousInputsState><m-selectedChannels>-1</m-selectedChannels><m-channelValues-0to1 xsi:type=\"SOAP-ENC:Array\" SOAP-ENC:arrayType=\"xsd:double[12]\"><item>0.5</item><item>0.5</item><item>0</item><item>0.5</item><item>0.5</item><item>0</item><item>0</item><item>0</item><item>0</item><item>0.5</item><item>0.5</item><item>0.5</item></m-channelValues-0to1></m-previousInputsState><m-aircraftState><m-currentPhysicsTime-SEC>708.01227736799046</m-currentPhysicsTime-SEC><m-currentPhysicsSpeedMultiplier>1</m-currentPhysicsSpeedMultiplier><m-airspeed-MPS>0.0021798373622661884</m-airspeed-MPS><m-altitudeAGL-MTR>0.14938228996838809</m-altitudeAGL-MTR><m-groundspeed-MPS>0.00014266304921026299</m-groundspeed-MPS><m-rollRate-DEGpSEC>0.77367656234457627</m-rollRate-DEGpSEC><m-yawRate-DEGpSEC>0.034366898669809132</m-yawRate-DEGpSEC><m-azimuth-DEG>71.528457641601562</m-azimuth-DEG><m-inclination-DEG>0.25129407644271851</m-inclination-DEG><m-roll-DEG>0.13396531343460083</m-roll-DEG><m-orientationQuaternion-Y>0.0022302858997136354</m-orientationQuaternion-Y><m-orientationQuaternion-Z>0.58445149660110474</m-orientationQuaternion-Z><m-orientationQuaternion-W>0.81142467260360718</m-orientationQuaternion-W><m-aircraftPositionX-MTR>34510.3515625</m-aircraftPositionX-MTR><m-aircraftPositionY-MTR>46654.50390625</m-aircraftPositionY-MTR><m-velocityWorldU-MPS>-0.00012938663712702692</m-velocityWorldU-MPS><m-velocityWorldV-MPS>6.0098616813775152E-005</m-velocityWorldV-MPS><m-velocityBodyU-MPS>-0.00010753551032394171</m-velocityBodyU-MPS><m-velocityBodyV-MPS>-9.8594442533794791E-005</m-velocityBodyV-MPS><m-velocityBodyW-MPS>0.0021749495062977076</m-velocityBodyW-MPS><m-accelerationWorldAX-MPS2>0.00080946780508384109</m-accelerationWorldAX-MPS2><m-accelerationWorldAY-MPS2>0.0046665812842547894</m-accelerationWorldAY-MPS2><m-accelerationWorldAZ-MPS2>8.8538541793823242</m-accelerationWorldAZ-MPS2><m-accelerationBodyAX-MPS2>0.018117452040314674</m-accelerationBodyAX-MPS2><m-accelerationBodyAY-MPS2>-0.060176290571689606</m-accelerationBodyAY-MPS2><m-accelerationBodyAZ-MPS2>-9.4150829315185547</m-accelerationBodyAZ-MPS2><m-windX-MPS>0</m-windX-MPS><m-windY-MPS>0</m-windY-MPS><m-windZ-MPS>0</m-windZ-MPS><m-propRPM>2075.375</m-propRPM><m-heliMainRotorRPM>-1</m-heliMainRotorRPM><m-batteryVoltage-VOLTS>12.519639647435969</m-batteryVoltage-VOLTS><m-batteryCurrentDraw-AMPS>0.44040951132774353</m-batteryCurrentDraw-AMPS><m-batteryRemainingCapacity-MAH>2473.21337890625</m-batteryRemainingCapacity-MAH><m-fuelRemaining-OZ>-1</m-fuelRemaining-OZ><m-isLocked>false</m-isLocked><m-hasLostComponents>false</m-hasLostComponents><m-anEngineIsRunning>true</m-anEngineIsRunning><m-isTouchingGround>true</m-isTouchingGround><m-flightAxisControllerIsActive>true</m-flightAxisControllerIsActive><m-currentAircraftStatus>CAS-WAITINGTOLAUNCH</m-currentAircraftStatus></m-aircraftState><m-notifications><m-resetButtonHasBeenPressed>false</m-resetButtonHasBeenPressed></m-notifications></ReturnData></SOAP-ENV:Body></SOAP-ENV:Envelope>"
  end

end

