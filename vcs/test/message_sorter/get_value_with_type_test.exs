defmodule Workshop.MessageQueueTest  do
  use ExUnit.Case

  setup do
    MessageSorter.System.start_link()
    {:ok, []}
  end

  test "Get Value with Type" do
    roll_config = %{
      name: :roll,
      default_message_behavior: :last,
      value_type: :number
    }
    pitch_config = %{
      name: :pitch,
      default_message_behavior: :default_value,
      default_value: 2.1,
      value_type: :number
    }
    # Start registry
    {:ok, pid} = Comms.ProcessRegistry.start_link()
    MessageSorter.System.start_sorter(roll_config)
    MessageSorter.System.start_sorter(pitch_config)
    Process.sleep(200)
    assert MessageSorter.Sorter.get_value(roll_config.name) == nil
    assert MessageSorter.Sorter.get_value(pitch_config.name) == pitch_config.default_value
    {roll_value, roll_type} = MessageSorter.Sorter.get_value_with_type(roll_config.name)
    assert roll_value == nil
    assert roll_type == :last
    new_roll_value = 1.1
    new_pitch_value = -0.5
    MessageSorter.Sorter.add_message(roll_config.name, [1],100,new_roll_value)
    MessageSorter.Sorter.add_message(pitch_config.name, [1],100,new_pitch_value)
    Process.sleep(50)
    {roll_value, roll_type} = MessageSorter.Sorter.get_value_with_type(roll_config.name)
    {pitch_value, pitch_type} = MessageSorter.Sorter.get_value_with_type(pitch_config.name)
    assert roll_value == new_roll_value
    assert roll_type == :current
    assert pitch_value == new_pitch_value
    assert pitch_type == :current
    Process.sleep(100)
    {roll_value, roll_type} = MessageSorter.Sorter.get_value_with_type(roll_config.name)
    {pitch_value, pitch_type} = MessageSorter.Sorter.get_value_with_type(pitch_config.name)
    assert roll_value == new_roll_value
    assert roll_type == :last
    assert pitch_value == pitch_config.default_value
    assert pitch_type == :default_value

  end
end
