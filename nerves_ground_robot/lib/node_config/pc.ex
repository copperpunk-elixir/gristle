defmodule NodeConfig.Pc do
  def get_config() do
    # --- COMMS ---
    comms = %{
      groups: [],
      interface: :wlp0s20f3,
      broadcast_timer_interval_ms: 60000,
      cookie: NodeConfig.Master.get_cookie()
    }
    # --- RETURN ---
    %{
      comms: comms,
    }
  end
end
