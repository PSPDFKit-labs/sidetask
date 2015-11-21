defmodule SideTask.SupervisorTest do
  use ExUnit.Case

  @resource :supervisor_test_resource

  # Setup a sidejob resource and start a child that links to parent but doesn't return {:ok, pid}
  # The supervisor should not shut down.
  # See https://github.com/basho/sidejob/pull/12
  test "doesn't shut down if start_child fails" do
    {:ok, _} = Application.ensure_all_started(:sidejob)
    {:ok, _} = :sidejob.new_resource(@resource, SideTask.Supervisor, 5, 1)
    {worker_reg} = @resource.workers()
    worker_pid = Process.whereis(worker_reg)
    assert Process.alive?(worker_pid)
    {:ok, :undefined} = SideTask.Supervisor.start_child(@resource, __MODULE__, :fail_to_start_link, [])
    SideTask.Supervisor.which_children(@resource) # wait for sidejob_supervisor to process the EXIT
    assert Process.alive?(worker_pid)
  end

  def fail_to_start_link() do
    spawn_link(fn -> :ok end)
    :ignore
  end
end
