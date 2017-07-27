defmodule Wizard.Subscriber.Server do
  alias Wizard.Subscriber
  alias Subscriber.Syncer
  use GenServer
  require Logger

  def init(%Subscriber{} = subscriber) do
    {:ok, %{
      subscriber: subscriber,
      insync: nil
    }}
  end

  def start_link(%Subscriber{} = subscriber) do
    GenServer.start_link(__MODULE__, subscriber, [])
  end

  def handle_cast(:sync, %{insync: nil, subscriber: subscriber} = state) do
    {:ok, pid} = Syncer.start_link(subscriber)
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
