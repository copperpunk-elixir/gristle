defmodule Realflight.SoapRequestTest do
  use ExUnit.Case
  require Logger
  setup do
    RingLogger.attach()
    Comms.System.start_link()
    Simulation.Realflight.start()
    {:ok, []}
  end

  test "Soap Request test", context do
    url = "192.168.7.136:18083"
    body = "<?xml version='1.0' encoding='UTF-8'?>
    <soap:Envelope xmlns:soap='http://schemas.xmlsoap.org/soap/envelope/' xmlns:xsd='http://www.w3.org/2001/XMLSchema' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>
    <soap:Body>
    <ResetAircraft><a>1</a><b>2</b></ResetAircraft>
    </soap:Body>
    </soap:Envelope>)"
    # Simulation.Realflight.reset_aircraft()
    Process.sleep(100)
    Simulation.Realflight.restore_controller()
    Process.sleep(100)
    Simulation.Realflight.inject_controller_interface()
    Process.sleep(100)
    Simulation.Realflight.set_throttle(1.0)
    Process.sleep(5000)
    Simulation.Realflight.set_throttle(0.0)
    Process.sleep(100)
    Simulation.Realflight.restore_controller()
    # Logger.debug("body: #{inspect(body)}")
    # {:ok, response} = HTTPoison.post(url, body)
    # Logger.debug("#{inspect(response)}")
    # assert length(response) > 0
    Process.sleep(5200)
  end
end
