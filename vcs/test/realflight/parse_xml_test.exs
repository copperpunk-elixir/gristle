defmodule Realflight.ParseXmlTest do
  use ExUnit.Case
  require Logger

  @default_latitude 41.769201
  @default_longitude -122.506394

  setup do
    RingLogger.attach()
    {:ok, []}
  end

  test "all or nothing extraction test" do
    Logger.info("bad xml")
    xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><SOAP-ENV:Body><ReturnData><m-previousInputsState><m-selectedChannels>-1</m-selectedChannels><m-channelValues-0to1 xsi:type=\"SOAP-ENC:Array\" SOAP-ENC:arrayType=\"xsd:double[12]\"><item>0.5</item><item>0.5</item><item>0</item><item>0.5</item><item>0.5</item><item>0</item><item>0</item><item>0</item><item>0</item><item>0.5</item><item>0.5</item><item>0.5</item></m-channelValues-0to1></m-previousInputsState><m-aircraftState><m-currentPhysicsTime-SEC>708.01227736799046</m-currentPhysicsTime-SEC><m-currentPhysicsSpeedMultiplier>1</m-currentPhysicsSpeedMultiplier><m-airspeed-MPS>0.0021798373622661884</m-airspeed-MPS><m-altitudeAGL-MTR>0.14938228996838809</m-altitudeAGL-MTR><m-groundspeed-MPS>0.00014266304921026299</m-groundspeed-MPS><m-rollRate-DEGpSEC>0.77367656234457627</m-rollRate-DEGpSEC><m-yawRate-DEGpSEC>0.034366898669809132</m-yawRate-DEGpSEC><m-azimuth-DEG>71.528457641601562</m-azimuth-DEG><m-inclination-DEG>0.25129407644271851</m-inclination-DEG><m-roll-DEG>0.13396531343460083</m-roll-DEG><m-orientationQuaternion-Y>0.0022302858997136354</m-orientationQuaternion-Y><m-orientationQuaternion-Z>0.58445149660110474</m-orientationQuaternion-Z><m-orientationQuaternion-W>0.81142467260360718</m-orientationQuaternion-W><m-aircraftPositionX-MTR>34510.3515625</m-aircraftPositionX-MTR><m-aircraftPositionY-MTR>46654.50390625</m-aircraftPositionY-MTR><m-velocityWorldU-MPS>-0.00012938663712702692</m-velocityWorldU-MPS><m-velocityWorldV-MPS>6.0098616813775152E-005</m-velocityWorldV-MPS><m-velocityBodyU-MPS>-0.00010753551032394171</m-velocityBodyU-MPS><m-velocityBodyV-MPS>-9.8594442533794791E-005</m-velocityBodyV-MPS><m-velocityBodyW-MPS>0.0021749495062977076</m-velocityBodyW-MPS><m-accelerationWorldAX-MPS2>0.00080946780508384109</m-accelerationWorldAX-MPS2><m-accelerationWorldAY-MPS2>0.0046665812842547894</m-accelerationWorldAY-MPS2><m-accelerationWorldAZ-MPS2>8.8538541793823242</m-accelerationWorldAZ-MPS2><m-accelerationBodyAX-MPS2>0.018117452040314674</m-accelerationBodyAX-MPS2><m-accelerationBodyAY-MPS2>-0.060176290571689606</m-accelerationBodyAY-MPS2><m-accelerationBodyAZ-MPS2>-9.4150829315185547</m-accelerationBodyAZ-MPS2><m-windX-MPS>0</m-windX-MPS><m-windY-MPS>0</m-windY-MPS><m-windZ-MPS>0</m-windZ-MPS><m-propRPM>2075.375</m-propRPM><m-heliMainRotorRPM>-1</m-heliMainRotorRPM><m-batteryVoltage-VOLTS>12.519639647435969</m-batteryVoltage-VOLTS><m-batteryCurrentDraw-AMPS>0.44040951132774353</m-batteryCurrentDraw-AMPS><m-batteryRemainingCapacity-MAH>2473.21337890625</m-batteryRemainingCapacity-MAH><m-fuelRemaining-OZ>-1</m-fuelRemaining-OZ><m-isLocked>false</m-isLocked><m-hasLostComponents>false</m-hasLostComponents><m-anEngineIsRunning>true</m-anEngineIsRunning><m-isTouchingGround>true</m-isTouchingGround><m-flightAxisControllerIsActive>true</m-flightAxisControllerIsActive><m-currentAircraftStatus>CAS-WAITINGTOLAUNCH</m-currentAircraftStatus></m-aircraftState><m-notifications><m-resetButtonHasBeenPressed>false</m-resetButtonHasBeenPressed></m-notifications></ReturnData></SOAP-ENV:Body></SOAP-ENV:Envelope>"
    xml_map =
      case SAXMap.from_string(xml) do
        {:ok, result} -> result
        _other -> %{}
      end
    return_data = get_in(xml_map, Simulation.Realflight.return_data_path())
    aircraft_state = get_in(return_data, Simulation.Realflight.aircraft_state_path())
    rcin_values = get_in(return_data, Simulation.Realflight.rcin_path())
    position_origin = Common.Utils.LatLonAlt.new_deg(@default_latitude, @default_longitude)
    position = Simulation.Realflight.extract_position(aircraft_state, position_origin)
    Logger.debug("position: #{inspect(position)}")
  end

  test "SOAP parse test" do
    Logger.info("good xml")
    xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns:SOAP-ENC=\"http://schemas.xmlsoap.org/soap/encoding/\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"><SOAP-ENV:Body><ReturnData><m-previousInputsState><m-selectedChannels>-1</m-selectedChannels><m-channelValues-0to1 xsi:type=\"SOAP-ENC:Array\" SOAP-ENC:arrayType=\"xsd:double[12]\"><item>0.5</item><item>0.5</item><item>0</item><item>0.5</item><item>0.5</item><item>0</item><item>0</item><item>0</item><item>0</item><item>0.5</item><item>0.5</item><item>0.5</item></m-channelValues-0to1></m-previousInputsState><m-aircraftState><m-currentPhysicsTime-SEC>708.01227736799046</m-currentPhysicsTime-SEC><m-currentPhysicsSpeedMultiplier>1</m-currentPhysicsSpeedMultiplier><m-airspeed-MPS>0.0021798373622661884</m-airspeed-MPS><m-altitudeASL-MTR>0.14938228996838809</m-altitudeASL-MTR><m-altitudeAGL-MTR>0.14938228996838809</m-altitudeAGL-MTR><m-groundspeed-MPS>0.00014266304921026299</m-groundspeed-MPS><m-pitchRate-DEGpSEC>-0.49789883184564587</m-pitchRate-DEGpSEC><m-rollRate-DEGpSEC>0.77367656234457627</m-rollRate-DEGpSEC><m-yawRate-DEGpSEC>0.034366898669809132</m-yawRate-DEGpSEC><m-azimuth-DEG>71.528457641601562</m-azimuth-DEG><m-inclination-DEG>0.25129407644271851</m-inclination-DEG><m-roll-DEG>0.13396531343460083</m-roll-DEG><m-orientationQuaternion-X>0.0010961623629555106</m-orientationQuaternion-X><m-orientationQuaternion-Y>0.0022302858997136354</m-orientationQuaternion-Y><m-orientationQuaternion-Z>0.58445149660110474</m-orientationQuaternion-Z><m-orientationQuaternion-W>0.81142467260360718</m-orientationQuaternion-W><m-aircraftPositionX-MTR>34510.3515625</m-aircraftPositionX-MTR><m-aircraftPositionY-MTR>46654.50390625</m-aircraftPositionY-MTR><m-velocityWorldU-MPS>-0.00012938663712702692</m-velocityWorldU-MPS><m-velocityWorldV-MPS>6.0098616813775152E-005</m-velocityWorldV-MPS><m-velocityWorldW-MPS>0.0021751639433205128</m-velocityWorldW-MPS><m-velocityBodyU-MPS>-0.00010753551032394171</m-velocityBodyU-MPS><m-velocityBodyV-MPS>-9.8594442533794791E-005</m-velocityBodyV-MPS><m-velocityBodyW-MPS>0.0021749495062977076</m-velocityBodyW-MPS><m-accelerationWorldAX-MPS2>0.00080946780508384109</m-accelerationWorldAX-MPS2><m-accelerationWorldAY-MPS2>0.0046665812842547894</m-accelerationWorldAY-MPS2><m-accelerationWorldAZ-MPS2>8.8538541793823242</m-accelerationWorldAZ-MPS2><m-accelerationBodyAX-MPS2>0.018117452040314674</m-accelerationBodyAX-MPS2><m-accelerationBodyAY-MPS2>-0.060176290571689606</m-accelerationBodyAY-MPS2><m-accelerationBodyAZ-MPS2>-9.4150829315185547</m-accelerationBodyAZ-MPS2><m-windX-MPS>0</m-windX-MPS><m-windY-MPS>0</m-windY-MPS><m-windZ-MPS>0</m-windZ-MPS><m-propRPM>2075.375</m-propRPM><m-heliMainRotorRPM>-1</m-heliMainRotorRPM><m-batteryVoltage-VOLTS>12.519639647435969</m-batteryVoltage-VOLTS><m-batteryCurrentDraw-AMPS>0.44040951132774353</m-batteryCurrentDraw-AMPS><m-batteryRemainingCapacity-MAH>2473.21337890625</m-batteryRemainingCapacity-MAH><m-fuelRemaining-OZ>-1</m-fuelRemaining-OZ><m-isLocked>false</m-isLocked><m-hasLostComponents>false</m-hasLostComponents><m-anEngineIsRunning>true</m-anEngineIsRunning><m-isTouchingGround>true</m-isTouchingGround><m-flightAxisControllerIsActive>true</m-flightAxisControllerIsActive><m-currentAircraftStatus>CAS-WAITINGTOLAUNCH</m-currentAircraftStatus></m-aircraftState><m-notifications><m-resetButtonHasBeenPressed>false</m-resetButtonHasBeenPressed></m-notifications></ReturnData></SOAP-ENV:Body></SOAP-ENV:Envelope>"
    xml_map =
      case SAXMap.from_string(xml) do
        {:ok, result} -> result
        _other -> %{}
      end
    position_origin = Common.Utils.LatLonAlt.new_deg(@default_latitude, @default_longitude)
    return_data = Simulation.Realflight.extract_from_path(xml_map, Simulation.Realflight.return_data_path())
    aircraft_state = Simulation.Realflight.extract_from_path(return_data, Simulation.Realflight.aircraft_state_path())
    # Logger.info("#{inspect(aircraft_state)}")
    Enum.each(aircraft_state, fn {k, v} -> IO.puts("#{k}: #{v}") end)
    rcin_values = get_in(return_data, Simulation.Realflight.rcin_path())
    position = Simulation.Realflight.extract_position(aircraft_state, position_origin)
    Logger.debug("position: #{Common.Utils.LatLonAlt.to_string(position)}")
    velocity = Simulation.Realflight.extract_velocity(aircraft_state)
    Logger.debug("velocity: #{inspect(velocity)}")
    attitude = Simulation.Realflight.extract_attitude(aircraft_state)
    Logger.debug("attitude: #{inspect(attitude)}")
    bodyrate = Simulation.Realflight.extract_bodyrate(aircraft_state)
    Logger.debug("bodyrate: #{inspect(Common.Utils.map_rad2deg(bodyrate))}")
    agl = Simulation.Realflight.extract_agl(aircraft_state)
    Logger.debug("agl: #{agl}")
    rcin = Simulation.Realflight.extract_rcin(rcin_values)
    Logger.debug("rcin: #{inspect(rcin)}")
    Process.sleep(200)
  end
end
