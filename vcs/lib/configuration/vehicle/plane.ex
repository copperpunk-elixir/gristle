defmodule Configuration.Vehicle.Plane do
  require Logger
  alias Configuration.Vehicle.Plane, as: Vehicle
  # def start_pv_cmds_message_sorters() do
  #   Logger.debug("Start Plane message sorters")
  #   MessageSorter.System.start_link()
  #   Enum.each(get_process_variable_list(), fn msg_sorter_config ->
  #     MessageSorter.System.start_sorter(msg_sorter_config)
  #   end)
  # end

  @spec get_sorter_configs() :: list()
  def get_sorter_configs() do
    Vehicle.Actuation.get_sorter_configs()
    |> Enum.concat(Vehicle.Control.get_sorter_configs())
    |> Enum.concat(Vehicle.Navigation.get_sorter_configs())
  end
end

