defmodule Params do
  @spec get_params() :: map()
  def get_params() do
    a = %{}
    %{y: apply(ParamsY, :get_y, [a])}
  end
end
