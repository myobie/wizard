defmodule Wizard.Subscriber.Server do
  alias Wizard.Subscriber
  alias Subscriber.Syncer
  alias Timex.Duration
  use GenServer
  require Logger

  @ten_seconds round(Duration.to_milliseconds(Duration.from_seconds(10)))
  @ten_minutes round(Duration.to_milliseconds(Duration.from_minutes(10)))

  def init(%Subscriber{} = subscriber) do
    {:ok, %{
      subscriber: subscriber,
      insync: nil,
      timer_ref: schedule_sync_for_later(nil, @ten_seconds)
    }}
  end

  def start_link(%Subscriber{} = subscriber) do
    GenServer.start_link(__MODULE__, subscriber, [])
  end

  @spec schedule_sync_for_later(reference | nil, non_neg_integer) :: reference
  defp schedule_sync_for_later(ref, wait \\ @ten_minutes) do
    cancel_timer(ref)
    Process.send_after(self(), :sync, wait)
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(ref), do: Process.cancel_timer(ref)

  def terminate(reason, %{timer_ref: timer_ref, insync: ref}) do
    cancel_timer(timer_ref)
    GenServer.stop(ref)
    reason
  end

  def handle_cast(:sync, %{insync: nil, subscriber: subscriber} = state) do
    {:ok, pid} = Syncer.start(subscriber)
    ref = Process.monitor(pid)
    GenServer.cast(pid, :sync)
    {:noreply, %{state | insync: ref}}
  end

  def handle_cast(:sync, %{insync: _} = state), do: {:noreply, state}

  # forward the info call to the cast call to support Process.send_after/3
  def handle_info(:sync, state), do: handle_cast(:sync, state)

  def handle_info({:DOWN, ref, :process, _pid, :normal}, %{insync: insync, timer_ref: timer_ref, subscriber: subscriber} = state) when insync == ref do
    Logger.debug("SYNC COMPLETE")
    subscriber = Subscriber.reload_subscription(subscriber)

    {:noreply,
     %{state | insync: nil,
       subscriber: subscriber,
       timer_ref: schedule_sync_for_later(timer_ref)}}
  end

  def handle_info({:DOWN, ref, :process, _pid, {:error, :unauthorized}}, %{insync: insync, timer_ref: timer_ref, subscriber: subscriber} = state) when insync == ref do
    Logger.debug("access_token is out of date")
    subscriber = Subscriber.reauthorize(subscriber)

    {:noreply,
     %{state | insync: nil,
       subscriber: subscriber,
       timer_ref: schedule_sync_for_later(timer_ref, @ten_seconds)}}
  end

  def handle_info({:DOWN, ref, :process, _pid, {:error, %HTTPoison.Error{reason: :timeout}}}, %{insync: insync, timer_ref: timer_ref} = state) when insync == ref do
    Logger.error "Sync request timed out, will retry"

    {:noreply,
     %{state | insync: nil,
       timer_ref: schedule_sync_for_later(timer_ref, @ten_seconds)}}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{insync: insync, timer_ref: timer_ref} = state) when insync == ref do
    Logger.debug("the sync process crashed, reason: #{inspect reason}")

    {:noreply,
     %{state | insync: nil,
       timer_ref: schedule_sync_for_later(timer_ref)}}
  end
end
