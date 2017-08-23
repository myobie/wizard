defmodule Wizard.Previews.Generator do
  require Logger
  alias Wizard.Feeds
  alias Wizard.Feeds.Event
  alias Wizard.RemoteStorage
  alias Wizard.Previews
  alias Wizard.Previews.ExportedFile
  alias Wizard.Previews.Generator.Server

  def start_link, do: Server.start_link

  @spec process(Event.t) :: {:ok, list(ExportedFile.t)} | {:error, atom}
  def process(%Event{} = event) do
    event = preload_event(event)

    with {:ok, download} <- download(event),
      {:ok, files} <- export_sketch(download, event),
      {:ok, files} <- put_exported_files(files),
      {:ok, files} <- insert_previews_for_files(files)
    do
      Logger.debug inspect(files)
      {:ok, files}
    end
  end

  def preload_event(event) do
    event
    |> Feeds.preload_event_subject()
    |> Feeds.preload_event_subscription()
  end

  def insert_previews_for_files(files),
    do: Previews.insert_previews_for_files(files)

  def download(event),
    do: Previews.download(event.subject, event.subscription.user)

  def export_sketch(download, event),
    do: Previews.export_sketch(download.path, event)

  def put_exported_files(files),
    do: RemoteStorage.put_exported_files(files)
end
