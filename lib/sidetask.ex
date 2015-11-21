defmodule SideTask do
  @moduledoc ~S"""
  An alternative to Elixir's `Task.Supervisor` that uses Basho's `sidejob` library for better
  parallelism and to support capacity limiting.

  Elixir's `Task.Supervisor` is implemented as a single `:simple_one_for_one` supervisor with the
  individual `Task`s as children. This means starting a new task has to go through this single
  supervisor. Furthermore there is no limit to the number of workers that can be running at the same
  time.

  Basho's `sidejob` library spawns multiple supervisors (one for each scheduler by default) and
  uses ETS tables to keep track of the number of workers, thereby making it possible to start
  workers in parallel while also putting an upper bound on the number of running workers.

  This module provides an API similar to `Task.Supervisor`, with the addition that all calls that
  start a new task require a sidejob resource as argument and can return `{:error, :overload}`.

  The `add_resource/2` and `delete_resource/1` functions are provided as convenience.

  Name Registration
  A sidejob resource registers multiple local names. Read more about it in the sidejob docs.
  """

  @typedoc "The sidejob resource"
  @type resource :: atom

  @doc """
  Create a new sidejob resource that enforces the requested usage limit.

  See `:sidejob.new_resource/4` for details.
  """
  @spec add_resource(resource, non_neg_integer) :: :ok
  def add_resource(name, limit) when is_atom(name) and is_integer(limit) do
    {:ok, _} = :sidejob.new_resource(name, SideTask.Supervisor, limit)
    :ok
  end

  @doc """
  Deletes an existing sidejob resource.
  """
  @spec delete_resource(resource) :: :ok | {:error, error}
        when error: :not_found | :running | :restarting
  def delete_resource(name) when is_atom(name) do
    case Supervisor.terminate_child(:sidejob_sup, name) do
      :ok -> Supervisor.delete_child(:sidejob_sup, name)
      error -> error
    end
  end

  @doc """
  Starts a task that can be awaited on as child of the given `sidejob_resource`
  """
  @spec async(resource, fun) :: {:ok, Task.t} | {:error, :overload}
  def async(sidejob_resource, fun) do
    async(sidejob_resource, :erlang, :apply, [fun, []])
  end

  @doc """
  Starts a task that can be awaited on as child of the given `sidejob_resource`
  """
  @spec async(resource, module, atom, [term]) :: {:ok, Task.t} | {:error, :overload}
  def async(sidejob_resource, module, fun, args) do
    args = [self, get_info(self), {module, fun, args}]
    case SideTask.Supervisor.start_child(sidejob_resource, Task.Supervised, :start_link, args) do
      {:ok, pid} ->
        ref = Process.monitor(pid)
        send pid, {self(), ref}
        {:ok, %Task{pid: pid, ref: ref}}
      {:error, :overload} -> {:error, :overload}
    end
  end

  @doc """
  Starts a task as child of the given `sidejob_resource`.

  Note that the spawned process is not linked to the caller, but only to the sidejob resource's
  supervisor.
  """
  @spec start_child(resource, fun) :: {:ok, pid} | {:error, :overload}
  def start_child(sidejob_resource, fun) do
    start_child(sidejob_resource, :erlang, :apply, [fun, []])
  end

  @doc """
  Starts a task as child of the given `sidejob_resource`.

  Note that the spawned process is not linked to the caller, but only to the sidejob resource's
  supervisor.
  """
  @spec start_child(resource, module, atom, [term]) :: {:ok, pid} | {:error, :overload}
  def start_child(sidejob_resource, module, fun, args) do
    args = [get_info(self), {module, fun, args}]
    SideTask.Supervisor.start_child(sidejob_resource, Task.Supervised, :start_link, args)
  end

  # from Task.Supervisor.get_info
  defp get_info(self) do
    {node(),
     case Process.info(self, :registered_name) do
       {:registered_name, []} -> self()
       {:registered_name, name} -> name
     end}
  end
end
