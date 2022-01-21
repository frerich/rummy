defmodule Rummy.ProcessMonitor do
  @moduledoc false

  use GenServer

  def start_link(_params) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def watch(pid, fun) do
    GenServer.cast(__MODULE__, {:watch, pid, fun})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:watch, pid, fun}, monitored_pids) do
    Process.monitor(pid)
    {:noreply, Map.put(monitored_pids, pid, fun)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, object, reason}, monitored_pids) do
    {fun, monitored_pids} = Map.pop!(monitored_pids, object)
    fun.(reason)
    {:noreply, monitored_pids}
  end
end
