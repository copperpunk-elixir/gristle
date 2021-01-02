defmodule Navigation.Path.Utils do
  @spec orbit(atom(), struct(), float(), boolean()) :: map()
  def orbit(type, position, radius, confirmation) do
    %{
      class: :orbit,
      type: type,
      position: position,
      radius: radius,
      confirmation: confirmation
    }
  end
end
