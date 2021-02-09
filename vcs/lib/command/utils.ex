defmodule Command.Utils do
  defmacro cs_rates, do: 1
  defmacro cs_attitude, do: 2
  defmacro cs_sca, do: 3

  defmacro cs_direct_manual, do: 100
  defmacro cs_direct_semi_auto, do: 101
  defmacro cs_direct_auto, do: 102

  defmacro pcm_manual, do: 0
  defmacro pcm_semi_auto, do: 1
  defmacro pcm_auto, do: 2
end
