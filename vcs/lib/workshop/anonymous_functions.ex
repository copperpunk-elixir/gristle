defmodule Workshop.AnonymousFunctions do
  def single_var() do
    Enum.each(1..10,&(IO.puts(&1+1)))
  end

  def double_var() do
    y = 1..5
    Enum.reduce(y, 1,&(&1*&2))
  end

  def lambda() do
    my_fun = fn map_entry ->
      {key, value} = map_entry
      IO.puts("#{key}: #{value}")
    end

    m =%{x: 10, y: 20, z: 35}
    Enum.each(m,my_fun)
  end

end
