defmodule Configuration.Module.Display.Scenic do
  @spec get_config(atom(), atom()) :: map()
  def get_config(model_type, _node_type) do
    %{
      vehicle_type: Common.Utils.Configuration.get_vehicle_type(model_type)
    }
  end
end
