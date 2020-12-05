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
    xml = Simulation.Realflight.get_deficient_xml()
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
    xml = Simulation.Realflight.get_test_xml()
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
