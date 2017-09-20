defmodule Wizard.Previews.Generator.Server do
  use GenServer
  require Logger
  import Ecto.Query
  alias Wizard.Repo
  alias Wizard.Feeds.Event
  alias Wizard.Previews.Generator

  def init(_) do
    events = from(e in Event,
                  where: e.preview_state == "pending",
                  order_by: [desc: :id],
                  limit: 50)
             |> Repo.all()

    work_soon()
    {:ok, %{events: events,
            retry_count: 0,
            current_event: nil,
            task: nil}}
  end

  def process(event) do
    case Generator.process(event) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def handle_cast({:process, event},
                  %{events: events, task: task} = state) do
    Logger.debug "handling a :process request"

    unless task, do: work_soon()

    # TODO: dedup events here
    {:noreply, %{state | events: events ++ [event]}}
  end

  def handle_info(:work, %{events: [event | events],
                           task: nil,
                           current_event: nil} = state) do
    task = Task.async(__MODULE__, :process, [event])
    # FIXME: it's possible for the task to run forever!
    {:noreply, %{state | events: events, task: task, current_event: event}}
  end
  def handle_info(:work, state), do: {:noreply, state}

  def handle_info({ref, :ok},
                  %{task: %{ref: task_ref},
                    current_event: current_event} = state)
  when ref == task_ref
  do
    Wizard.Feeds.update_event_preview_state(current_event, "complete")

    Logger.debug "Finishing processing previews for event #{inspect current_event}\n\n\n"

    {:noreply, %{state | current_event: nil, retry_count: 0}}
  end

  def handle_info({ref, {:error, error}},
                  %{task: %{ref: task_ref},
                    events: events,
                    current_event: current_event,
                    retry_count: retry_count} = state)
                  when ref == task_ref do
    Logger.error "Error (#{inspect error}) processing previews for event #{inspect current_event}\n\n\n"

    state = if retry_count > 3 do
      Wizard.Feeds.update_event_preview_state(current_event, "failed")
      %{state | current_event: nil, retry_count: 0}
    else
      retry_count = retry_count + 1
      events = [current_event | events]
      %{state | events: events, current_event: nil, retry_count: retry_count}
    end

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, :normal},
                  %{task: %{ref: task_ref}, events: events} = state)
                  when ref == task_ref do

    Logger.debug "Task is down"

    if length(events) > 0, do: work_soon()

    {:noreply, %{state | task: nil}}
  end

  defp work_soon do
    Logger.debug "Will work soon"
    Process.send_after(self(), :work, 1000)
  end

  def start_link do
    GenServer.start_link(__MODULE__, nil, [name: __MODULE__])
  end
end
