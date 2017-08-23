defmodule Wizard.Previews.Generator do
  require Logger
  alias Wizard.Feeds
  alias Wizard.RemoteStorage
  alias Wizard.Previews
  alias Wizard.Previews.ExportedFile
  alias Wizard.Previews.Generator.Server

  def start_link, do: Server.start_link

  @spec process(Feeds.Event.t) :: {:ok, list(ExportedFile.t)} | {:error, atom}
  def process(%Feeds.Event{} = event) do
    # NOTE: the assumption is that all events
    # are a sharepoint item and are sketch files

    with {:ok, download} <- Previews.download(event),
      {:ok, files} <- Previews.export_sketch_artboards_to_files(download),
      {:ok, uploads} <- RemoteStorage.put_exported_files(files),
      {:ok, previews} <- Previews.insert_previews_for_uploads(uploads)
    do
      {:ok, previews}
    end
  end
end
