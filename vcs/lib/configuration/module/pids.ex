defmodule Configuration.Module.Pids do
  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, _node_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)
    vehicle_module =
      Module.concat(Configuration.Vehicle, String.to_existing_atom(vehicle_type))
      |> Module.concat(Pids)
    pids = apply(vehicle_module, :get_pids, [model_type])
    [
      pids: pids,
    ]
  end
end
