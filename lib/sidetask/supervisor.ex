defmodule SideTask.Supervisor do
  @moduledoc ~S"""
  Elixir port of Basho's sidejob_supervisor, using a map as a set instead of `:sets` for better
  performance and including the not-yet-upstreamed bugfix https://github.com/basho/sidejob/pull/12
  """

  use GenServer

  @spec start_child(SideTask.resource, module, atom, term) :: {:ok, pid} |
                                                              {:error, :overload} |
                                                              {:error, term}
  def start_child(name, mod, fun, args) do
    case :sidejob.call(name, {:start_child, mod, fun, args}, :infinity) do
      :overload -> {:error, :overload};
      other -> other
    end
  end

  @spec which_children(SideTask.resource) :: [pid]
  def which_children(name) do
    workers = :erlang.tuple_to_list(name.workers())
    children = for worker <- workers, do: GenServer.call(worker, :get_children)
    List.flatten(children)
  end

  ## GenServer callbacks

  def init([name]) do
    Process.flag(:trap_exit, true)
    state = %{
      name: name,
      children: %{},
      spawned: 0,
      died: 0,
    }
    {:ok, state}
  end

  def handle_call(:get_children, _from, %{children: children} = state) do
    {:reply, Map.keys(children), state}
  end

  def handle_call({:start_child, mod, fun, args}, _from, state)
  do
    # in order to be compatible with Erlang's `supervisor` we emulate the `catch` keyword.
    # c.f. http://erlang.org/doc/reference_manual/expressions.html#id81036
    result = try do
      apply(mod, fun, args)
    catch
      :error, reason -> {:'EXIT', {reason, System.stacktrace}}
      :exit, term -> {:'EXIT', term}
      :throw, term -> term
    end
    case result do
      {:ok, pid} when is_pid(pid) ->
        {:reply, {:ok, pid}, add_child(pid, state)}
      {:ok, pid, extra} when is_pid(pid) ->
        {:reply, {:ok, pid, extra}, add_child(pid, state)}
      :ignore ->
        {:reply, {:ok, :undefined}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
      reason ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_request, state) do
    {:noreply, state}
  end

  def handle_info({:'EXIT', pid, _reason}, state) do
    {:noreply, remove_child(pid, state)}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  def current_usage(%{children: children} = _state) do
    {:message_queue_len, pending} = Process.info(self(), :message_queue_len)
    current = Map.size(children)
    pending + current
  end

  def rate(%{spawned: spawned, died: died} = state) do
    state = %{state | spawned: 0, died: 0}
    {spawned, died, state}
  end

  defp add_child(pid, %{children: children, spawned: spawned} = state) do
    %{state | children: Map.put(children, pid, true), spawned: spawned + 1}
  end

  defp remove_child(pid, %{children: children, died: died} = state) do
    %{state | children: Map.delete(children, pid), died: died + 1}
  end
end
