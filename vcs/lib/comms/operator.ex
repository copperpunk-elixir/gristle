defmodule Comms.Operator do
  use GenServer
  require Logger

  @default_refresh_groups_loop_interval_ms 100

  def start_link(config \\ %{}) do
    Logger.debug("Start CommsOperator")
    Process.sleep(100)
    {:ok, pid} = Common.Utils.start_link_redudant(GenServer, __MODULE__, config, __MODULE__)
    start_refresh_loop()
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    {:ok, %{
        refresh_groups_loop_interval_ms: Map.get(config, :refresh_groups_loop_interval_ms, @default_refresh_groups_loop_interval_ms),
        refresh_groups_timer: nil,
        groups: %{},#Map.get(config, :groups, %{}),
        message_count: 0 # this is purely for diagnostics
     }}
  end

  def handle_cast(:start_refresh_loop, state) do
    refresh_groups_timer = Common.Utils.start_loop(self(), state.refresh_groups_loop_interval_ms, :refresh_groups)
    {:noreply, %{state | refresh_groups_timer: refresh_groups_timer}}
  end

  @impl GenServer
  def handle_cast(:stop_refresh_loop, state) do
    refresh_groups_timer = Common.Utils.stop_loop(state.refresh_groups_timer)
    {:noreply, %{state | refresh_groups_timer: refresh_groups_timer}}
  end

  @impl GenServer
  def handle_cast({:join_group, group, process_id}, state) do
    # We will be added to our own record of the group during the
    # :refresh_groups cycle
    Logger.debug("Join group: #{inspect(group)}")
    :pg2.create(group)
    if !is_in_group?(group, process_id) do
      :pg2.join(group, process_id)
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:leave_group, group, process_id}, state) do
    # We will be remove from our own record of the group during the
    # :refresh_groups cycle
    if is_in_group?(group, process_id) do
      :pg2.leave(group, process_id)
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:send_msg_to_group, message, group, sender}, state) do
    members = Map.get(state.groups, group, [])
    Logger.debug("Group memebers: #{inspect(members)}")
    Enum.each(members, fn dest ->
      if dest != sender do
        Logger.debug("Send #{inspect(message)} to #{inspect(dest)}")
        GenServer.cast(dest, message)
      end
    end)
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:get_members, group}, _from, state) do
    {:reply, Map.get(state.groups, group, []), state}
  end

  @impl GenServer
  def handle_call(:get_all_groups_and_members, _from, state) do
    {:reply, state.groups, state}
  end

  @impl GenServer
  def handle_call(:get_message_count, _from, state) do
    {:reply, state.message_count, state}
  end

  @impl GenServer
  def handle_info(:refresh_groups, state) do
    groups =
      Enum.reduce(:pg2.which_groups, %{}, fn (group, acc) ->
        group_members = :pg2.get_members(group)
        Map.put(acc, group, group_members)
      end)
    Logger.warn("groups after refresh: #{inspect(groups)}")
    {:noreply, %{state | groups: groups}}
  end

  defp join_initial_groups() do
    GenServer.cast(__MODULE__, :join_initial_groups)
  end

  def start_refresh_loop() do
    GenServer.cast(__MODULE__, :start_refresh_loop)
  end

  def stop_refresh_loop() do
    GenServer.cast(__MODULE__, :stop_refresh_loop)
  end

  def join_group(group, process_id) do
    GenServer.cast(__MODULE__, {:join_group, group, process_id})
  end

  def leave_group(group, process_id) do
    GenServer.cast(__MODULE__, {:leave_group, group, process_id})
  end

  def send_msg_to_group(message, group, sender) do
    GenServer.cast(__MODULE__, {:send_msg_to_group, message, group, sender})
  end

  def is_in_group?(group, pid) do
    members =
      case :pg2.get_members(group) do
        {:error, _} -> []
        members -> members
      end
    Enum.member?(members, pid)
  end

  def get_members(group) do
    GenServer.call(__MODULE__, {:get_members, group})
  end

  def get_all_groups_and_members() do
    GenServer.call(__MODULE__, :get_all_groups_and_members)
  end

  def get_message_count() do
    GenServer.call(__MODULE__, :get_message_count)
  end
end
