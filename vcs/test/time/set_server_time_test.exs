defmodule Time.SetServerTimeTest do
  use ExUnit.Case
  require Logger

  setup do
    RingLogger.attach()
    Comms.System.start_link()
    Time.System.start_link(Configuration.Module.Time.get_config(nil,nil))
    Process.sleep(400)
    {:ok, []}
  end

  test "Set Server Time" do
    Logger.info("Set Server Time test")
    Comms.System.start_operator(__MODULE__)
    Process.sleep(500)
    # Set GPS Time Source
    gps_time_nano = round(3600*1.0e9)
    Comms.Operator.send_local_msg_to_group(__MODULE__, {:gps_time_source, gps_time_nano}, self())
    Process.sleep(600)
    datetime_exp = ~U[1980-01-01 01:00:00Z]
    datetime = Time.Server.get_gps_time_source()
    assert datetime.year == datetime_exp.year
    assert datetime.hour == datetime_exp.hour
    Process.sleep(1000)
    current_time = Time.Server.get_time()
    assert current_time.second > 0
    # Set GPS Time
    gps_time = ~U[1980-01-01 03:00:00Z]
    Comms.Operator.send_global_msg_to_group(__MODULE__, {:gps_time, gps_time}, self())
    Process.sleep(100)
    datetime_exp = ~U[1980-01-01 03:00:00Z]
    datetime = Time.Server.get_time()
    assert datetime.hour == datetime_exp.hour
    Process.sleep(1000)
    current_time = Time.Server.get_time()
    assert current_time.second > 0
  end
end
