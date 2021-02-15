defmodule Common.Utils.Configuration do
  require Logger

  @spec get_node_type() :: binary()
  def get_node_type() do
    "all"
  end

  @spec split_safely(binary(), binary()) :: list()
  def split_safely(value, delimitter)do
    # Logger.warn("split: #{value} with #{delimitter}")
    case String.split(value, delimitter) do
      [node_type, meta] -> [node_type, meta]
      [node_type] -> [node_type, nil]
    end
  end
end
