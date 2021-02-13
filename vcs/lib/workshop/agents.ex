defmodule Workshop.Agents do
  def start_link(name) do
    Agent.start_link(fn -> %{pv_cmd: nil, pv_value: nil, stuff: nil} end, name: via_tuple(name))
  end

  def get_and_update_agent(name, pv_cmd, pv_value, airspeed, dt) do
     # Agent.get_and_update(via_tuple(name), &(get_and_update(&1, pv_cmd, pv_value, airspeed, dt)))
     Agent.get_and_update(via_tuple(name), __MODULE__, :get_and_update, [pv_cmd, pv_value, airspeed, dt])
  end

  def update_agent(name, pv_cmd, pv_value, airspeed, dt) do
    # Agent.update(via_tuple(name), &(update(&1, pv_cmd, pv_value, airspeed, dt)))
    Agent.update(via_tuple(name), __MODULE__, :update, [pv_cmd, pv_value, airspeed, dt])
  end

  @spec get_and_update(map(), float(), float(), float(), float()) :: map()
  def get_and_update(state, pv_cmd, pv_value, airspeed, dt) do
    state = %{state | pv_cmd: pv_cmd, pv_value: pv_value, stuff: airspeed*dt}
    {state.pv_cmd, state}
  end


  @spec update(map(), float(), float(), float(), float()) :: map()
  def update(state, pv_cmd, pv_value, airspeed, dt) do
    %{state | pv_cmd: pv_cmd, pv_value: pv_value, stuff: airspeed*dt}
  end

  def get(name) do
    Agent.get(via_tuple(name), fn state -> state end)
  end

  @spec via_tuple(binary()) :: tuple()
  def via_tuple(name) do
    Comms.ProcessRegistry.via_tuple(__MODULE__,name)
  end
end
