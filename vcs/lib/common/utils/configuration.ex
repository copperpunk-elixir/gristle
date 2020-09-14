defmodule Common.Utils.Configuration do
  require Logger

  @spec get_vehicle_type(atom()) :: atom()
  def get_vehicle_type(model_type) do
    # Common.Utils.File.get_filenames_with_extension(".vehicle") |> Enum.at(0) |> String.to_atom()
    case model_type do
      :Cessna -> :Plane
      :EC1500 -> :Plane
      _other -> raise "Unknown model"
    end
  end

  @spec get_node_type() :: atom()
  def get_node_type() do
    Common.Utils.File.get_filenames_with_extension(".node") |> Enum.at(0) |> String.to_atom()
  end

  @spec get_model_type() :: atom()
  def get_model_type() do
    Common.Utils.File.get_filenames_with_extension(".model") |> Enum.at(0) |> String.to_atom()
  end

  @spec get_modules() :: list()
  def get_modules() do
    Common.Utils.File.get_filenames_with_extension(".module")
  end

  @spec get_uart_peripherals() :: list()
  def get_uart_peripherals() do
    peripherals_bin_list = Common.Utils.File.get_filenames_with_extension(".uart", "peripherals")
    Enum.map(peripherals_bin_list, fn x ->
      String.to_atom(x)
    end)
  end

  @spec get_gpio_peripherals() :: list()
  def get_gpio_peripherals() do
    peripherals_bin_list = Common.Utils.File.get_filenames_with_extension(".gpio", "peripherals")
    Enum.map(peripherals_bin_list, fn x ->
      String.to_atom(x)
    end)
  end

  @spec get_i2c_peripherals() :: list()
  def get_i2c_peripherals() do
    peripherals_bin_list = Common.Utils.File.get_filenames_with_extension(".i2c", "peripherals")
    Enum.map(peripherals_bin_list, fn x ->
      String.to_atom(x)
    end)
  end
end
