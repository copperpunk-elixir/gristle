defmodule Actuation.ActuationConfigTest do
  use ExUnit.Case
  require Logger
  setup do
    Common.Utils.common_startup()
    RingLogger.attach()
    model_type = "T28"
    MessageSorter.System.start_link(model_type)
    modules = [Actuation]
    # Configuration.Module.start_modules(modules, model_type, node_type)

    {:ok, [model_type: model_type]}
  end

  test "All test", context do
    # config = Configuration.Vehicle.get_actuation_config(:Plane, :all)
    config = Configuration.Module.get_config(Actuation, context[:model_type], "all")
    Enum.each(config[:sw_interface][:actuators], fn actuator ->
      Logger.debug("#{inspect(actuator)}")
    end)
    # Logger.info("config: #{inspect(config)}")
    Process.sleep(200)
  end

  test "Sim test", context do
    config = Configuration.Module.get_config(Actuation, context[:model_type], "sim")
    Enum.each(config[:sw_interface][:actuators], fn actuator ->
      Logger.debug("#{inspect(actuator)}")
    end)
    # Logger.info("config: #{inspect(config)}")
    Process.sleep(200)
  end

  test "Other test", context do
    config = Configuration.Module.get_config(Actuation, context[:model_type], "left_side")
    Enum.each(config[:sw_interface][:actuators], fn actuator ->
      Logger.debug("#{inspect(actuator)}")
    end)
    # Logger.info("config: #{inspect(config)}")
    Process.sleep(200)
  end


end
