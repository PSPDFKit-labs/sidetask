SideTask
========

[![Build Status](https://travis-ci.org/MSch/sidetask.svg)](https://travis-ci.org/MSch/sidetask)

SideTask is an alternative to Elixir's
[Task.Supervisor](http://elixir-lang.org/docs/stable/elixir/Task.Supervisor.html) that uses Basho's
[sidejob](https://github.com/basho/sidejob) library for better parallelism and to support capacity
limiting of [Tasks](http://elixir-lang.org/docs/stable/elixir/Task.html).

Elixir's `Task.Supervisor` is implemented as a single `:simple_one_for_one` supervisor with the
individual `Task`s as children. This means starting a new task has to go through this single
supervisor. Furthermore there is no limit to the number of workers that can be running at the same
time.

Basho's sidejob library spawns multiple supervisors (one for each scheduler by default) and
uses ETS tables to keep track of the number of workers, thereby making it possible to start
workers in parallel while also putting an upper bound on the number of running workers.

SideTask provides an API similar to `Task.Supervisor`, with the addition that all calls that
start a new task require a sidejob resource as argument and can return `{:error, :overload}`.

Convenience functions for adding and deleting sidejob resources are provided.

## Example 1

```elixir
SideTask.add_resource(:example1, 50)
potential_tasks = for i <- 1..100 do
  case SideTask.async(:example1, fn -> :timer.sleep(1000); i end) do
    {:ok, pid} ->
      IO.puts "Task #{i} created"
      pid
    {:error, :overload} ->
      IO.puts "Task #{i} not created, overloaded"
      nil
  end
end
IO.inspect for task = %Task{} <- potential_tasks, do: Task.await(task)
```

## Example 2

```elixir
# Erlang spawns one scheduler per CPU core by default
schedulers = :erlang.system_info(:schedulers)
SideTask.add_resource(:example2, schedulers * 2)
for scheduler <- 1..schedulers do
  spawn_link fn ->
    for i <- Stream.iterate(0, &(&1+1)) do
      SideTask.start_child :example2, fn ->
        :timer.sleep(250);
        IO.inspect scheduler: scheduler, count: i
      end
    end
  end
end
```

![Observer while running example 2](https://raw.githubusercontent.com/MSch/sidetask/gh-pages/observer.png)
