defmodule Wizard.Sharepoint.Subscriber.Server do
  alias Wizard.Sharepoint.Subscriber.Syncer
  use GenServer
  require Logger

  def init({drive, authorization}) do
    {:ok, %{
      drive: drive,
      authorization: authorization,
      insync: nil
    }}
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [])
  end

  def handle_cast(:sync, %{insync: nil, drive: drive, authorization: authorization} = state) do
    {:ok, pid} = Syncer.start_link({drive, authorization})
    ref = Process.monitor(pid)
    GenServer.cast(pid, :sync)
    {:noreply, %{state | insync: ref}}
  end

  def handle_cast(:sync, %{insync: _} = state), do: {:noreply, state}

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{insync: insync} = state) when insync == ref do
    Logger.debug("the sync process crashed, reason: #{reason}")
    {:noreply, %{state | insync: nil}}
  end

  def handle_info({:DOWN, ref, :process, _pid, :normal}, %{insync: insync} = state) when insync == ref do
    Logger.debug("SYNC COMPLETE")
    {:noreply, %{state | insync: nil}}
  end
end
