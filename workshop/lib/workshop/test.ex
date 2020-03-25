defmodule Workshop.Test do
  @pr_mod Process
  @pr_fn :info

  def variable_mfa() do
    IO.inspect(apply(@pr_mod, @pr_fn, [self()]))
  end

  def hello(name) do
    IO.puts("hello #{name}")
  end
end
