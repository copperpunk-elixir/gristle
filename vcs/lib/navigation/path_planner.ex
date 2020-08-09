defmodule Navigation.PathPlanner do
  use GenServer
  require Logger


  def start_link(config) do
    Logger.debug("Start Navigation.PathPlanner")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
    GenServer.cast(pid, :begin)
    {:ok, pid}
  end

  @impl GenServer
  def init(_config) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast(:begin, state) do
    Comms.System.start_operator(__MODULE__)
    {:noreply, state}
  end

  @spec load_mission(struct(), atom()) :: atom()
  def load_mission(mission, module) do
    Logger.info("load mission: #{inspect(mission.name)}")
    Comms.Operator.send_global_msg_to_group(
      module,
      {:load_mission, mission},
      :load_mission,
      self())
  end

  @spec load_seatac_34R(integer()) ::atom()
  def load_seatac_34R(num_wps \\ 1) do
    load_path_mission("seatac", "34R",:Cessna, nil, num_wps)
  end

  @spec load_montague_0L(any()) :: atom()
  def load_montague_0L(track_type_or_num_wps) do
    {track_type, num_wps} =
    if (is_atom(track_type_or_num_wps)) do
      {track_type_or_num_wps, 0}
    else
      {nil, track_type_or_num_wps}
    end
    load_path_mission("montague", "0L",:EC1500, track_type, num_wps)
  end

  @spec load_montague_18R(any()) :: atom()
  def load_montague_18R(track_type_or_num_wps) do
    {track_type, num_wps} =
    if (is_atom(track_type_or_num_wps)) do
      {track_type_or_num_wps, 0}
    else
      {nil, track_type_or_num_wps}
    end
    load_path_mission("montague", "18R",:EC1500, track_type, num_wps)
  end

  @spec load_path_mission(binary(), binary(), atom(), atom(), integer()) :: atom()
  def load_path_mission(airport, runway, aircraft_type, track_type, num_wps) do
    load_mission(Navigation.Path.Mission.get_complete_mission(airport, runway, aircraft_type, track_type, num_wps), __MODULE__)
  end
end
