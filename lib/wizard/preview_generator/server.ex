defmodule Wizard.PreviewGenerator.Server do
  use GenServer
  require Logger
  import Ecto.Query
  alias Wizard.Repo
  alias Wizard.Feeds.Event
  alias Wizard.PreviewGenerator

  def init(_) do
    events = from(e in Event, where: e.preview_state == "pending")
             |> Repo.all()

    work_soon()
    {:ok, %{events: events,
            task: nil}}
  end

  def handle_cast({:process, event}, _from, %{events: events, task: task} = state) do
    unless task, do: work_soon()
    {:noreply, %{state | events: events ++ [event]}}
  end

  def handle_info(:work, %{events: [event | events], task: nil} = state) do
    task = Task.async(PreviewGenerator, :process, [event])
    {:noreply, %{state | working: true, events: events, task: task}}
  end
  def handle_info(:work, state), do: {:ok, state}

  def handle_info({ref, {:ok, event}},
                  %{task: %{ref: task_ref, events: events}} = state)
                  when ref == task_ref do

    Logger.debug "Finishing processing previews for event #{inspect event}"

    if length(events) > 0, do: work_soon()

    {:noreply, %{state | task: nil}}
  end

  def handle_info({ref, {:error, error, event}},
                  %{task: %{ref: task_ref}, events: events} = state)
                  when ref == task_ref do

    Logger.error "Error processing previews for event #{inspect event} – #{inspect error}"

    work_soon()

    {:noreply, %{state | events: [event | events], task: nil}}
  end

  defp work_soon do
    Process.send_after(self(), :work, 100)
  end

  def start_link do
    GenServer.start_link(__MODULE__, nil, [name: __MODULE__])
  end
end
