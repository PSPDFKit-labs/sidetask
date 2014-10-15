defmodule SideTaskTest do
  use ExUnit.Case

  setup do
    SideTask.add_resource(:test, 3)
    on_exit fn -> SideTask.delete_resource(:test) end
    {:ok, resource: :test}
  end

  setup do
    Logger.remove_backend(:console)
    on_exit fn -> Logger.add_backend(:console, flush: true) end
    :ok
  end

  def wait_and_send(caller, atom) do
    send caller, :ready
    receive do: (true -> true)
    send caller, atom
  end

  test "async can trip sidejob's overload protection", config do
    # test that sidejob limits worker count and returns `{:error, :overload}` when overloaded.
    # sidejob's actual limit is number of scheduler * configured limit and is dependent on the
    # tick time of the individual sidejob workers, so we can just check that we get an overload
    # error some of the time if we request "too many" workers.
    acquired_workers = for _ <- 1..(:erlang.system_info(:schedulers)*4) do
      SideTask.async(config[:resource], fn -> :timer.sleep(100) end)
    end
    assert Enum.member?(acquired_workers, {:error, :overload})
  end

  test "start_child can trip sidejob's overload protection", config do
    # c.f. corresponding test for async
    acquired_workers = for _ <- 1..(:erlang.system_info(:schedulers)*4) do
      SideTask.async(config[:resource], fn -> :timer.sleep(100) end)
    end
    assert Enum.member?(acquired_workers, {:error, :overload})
  end


  ## Adapted tests from Task.SupervisorTest

  test "async/1", config do
    parent = self()
    fun = fn -> wait_and_send(parent, :done) end
    {:ok, task} = SideTask.async(config[:resource], fun)

    # Assert the struct
    assert task.__struct__ == Task
    assert is_pid task.pid
    assert is_reference task.ref

    # Assert the link
    {:links, links} = Process.info(self, :links)
    assert task.pid in links

    receive do: (:ready -> :ok)

    # Assert the initial call
    {:name, fun_name} = :erlang.fun_info(fun, :name)
    assert {__MODULE__, fun_name, 0} === :proc_lib.translate_initial_call(task.pid)

    # Run the task
    send task.pid, true

    # Assert response and monitoring messages
    ref = task.ref
    assert_receive {^ref, :done}
    assert_receive {:DOWN, ^ref, _, _, :normal}
  end

  test "async/3", config do
    {:ok, task} = SideTask.async(config[:resource], __MODULE__, :wait_and_send, [self(), :done])

    receive do: (:ready -> :ok)
    assert {__MODULE__, :wait_and_send, 2} === :proc_lib.translate_initial_call(task.pid)

    send task.pid, true
    assert task.__struct__ == Task
    assert Task.await(task) == :done
  end

  test "start_child/1", config do
    parent = self()
    fun = fn -> wait_and_send(parent, :done) end
    {:ok, pid} = SideTask.start_child(config[:resource], fun)

    {:links, links} = Process.info(self, :links)
    refute pid in links

    receive do: (:ready -> :ok)
    {:name, fun_name} = :erlang.fun_info(fun, :name)
    assert {__MODULE__, fun_name, 0} === :proc_lib.translate_initial_call(pid)

    send pid, true
    assert_receive :done
  end

  test "start_child/3", config do
    {:ok, pid} = SideTask.start_child(config[:resource], __MODULE__, :wait_and_send, [self(), :done])

    {:links, links} = Process.info(self, :links)
    refute pid in links

    receive do: (:ready -> :ok)
    assert {__MODULE__, :wait_and_send, 2} === :proc_lib.translate_initial_call(pid)

    send pid, true
    assert_receive :done
  end

  test "await/1 exits on task throw", config do
    Process.flag(:trap_exit, true)
    {:ok, task} = SideTask.async(config[:resource], fn -> throw :unknown end)
    assert {{{:nocatch, :unknown}, _}, {Task, :await, [^task, 5000]}} =
           catch_exit(Task.await(task))
  end

  test "await/1 exits on task error", config do
    Process.flag(:trap_exit, true)
    {:ok, task} = SideTask.async(config[:resource], fn -> raise "oops" end)
    assert {{%RuntimeError{}, _}, {Task, :await, [^task, 5000]}} =
           catch_exit(Task.await(task))
  end

  test "await/1 exits on task exit", config do
    Process.flag(:trap_exit, true)
    {:ok, task} = SideTask.async(config[:resource], fn -> exit :unknown end)
    assert {:unknown, {Task, :await, [^task, 5000]}} =
           catch_exit(Task.await(task))
  end
end
