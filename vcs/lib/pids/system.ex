defmodule Pids.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.info("Pids Supervisor start_link()")
    Comms.System.start_link()
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    pid_children = get_pids(config[:pids])
    children = [
      {Pids.Moderator, Keyword.drop(config, [:pids])},
    ] ++ pid_children
    Logger.warn("pid child specs: #{inspect(pid_children)}")
    Enum.each(pid_children, fn x ->
      Logger.info("child: #{inspect(x)}")
    end)
    Supervisor.init(children, strategy: :one_for_one)
  end

  def get_pids(pids) do
    Enum.reduce(pids, [], fn ({process_variable, control_variables}, acc) ->
      Enum.reduce(control_variables, acc, fn ({control_variable, single_config}, acc2) ->
        single_config = Keyword.put(single_config, :name, {process_variable, control_variable})
        Logger.debug("pid config: #{inspect(single_config)}")
        [Supervisor.child_spec({Pids.Pid, single_config}, id: single_config[:name])] ++ acc2
      end)
    end)
  end
end
