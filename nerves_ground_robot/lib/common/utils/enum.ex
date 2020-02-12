defmodule Common.Utils.Enum do
  require Logger

  def assert_list(value_or_list) do
    if is_list(value_or_list) do
      value_or_list
    else
      [value_or_list]
    end
  end

  def get_map_nested_inside_list_containing_key_value(search_list, search_key, search_value) do
    Enum.reduce(search_list, [], fn (nested_map, acc) ->
      # Logger.debug("map: #{inspect(map)}")
      if Map.get(nested_map, search_key) == search_value do
        nested_map
      else
        acc
      end
    end)
  end
end
