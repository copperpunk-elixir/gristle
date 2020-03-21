defmodule Workshop.Test do
  @pr_mod Process
  @pr_fn :info
  @pr_arg self()
  def hello(name) do
    IO.puts("hello #{name}")
  end

  def variable_mfa() do
    IO.inspect(apply(@pr_mod, @pr_fn, [@pr_arg]))
  end
end
