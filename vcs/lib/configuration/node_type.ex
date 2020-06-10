defmodule Configuration.NodeType do
  require Logger

  @spec get_node_type() :: atom()
  def get_node_type do
    System.cmd("mount", ["/dev/sda1", "/mnt"])
    {:ok, files} = :file.list_dir("/mnt")
    node_type = Enum.reduce(files,nil, fn (file, acc) ->
      file = to_string(file)
      if (String.contains?(file,".node")) do
        [node_type] = String.split(file,".node",[trim: true])
        node_type
      else
        acc
      end
    end)
    if (node_type == nil) do
      raise "Node Type is note available"
    end
    node_type
    |> String.to_atom()
  end
end
