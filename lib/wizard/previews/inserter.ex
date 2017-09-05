defmodule Wizard.Previews.Inserter do
  require Logger
  import Ecto.Query
  alias Wizard.Repo
  alias Ecto.Multi
  alias Wizard.Feeds
  alias Wizard.RemoteStorage
  alias Wizard.Previews.{ExportedFile, Download}

  @spec insert_previews_for_uploads(MapSet.t(RemoteStorage.Upload.t)) :: {:ok, MapSet.t(Feeds.Preview.t)} | {:error, atom}
  def insert_previews_for_uploads(uploads),
    do: insert_previews_for_list_of_uploads(Enum.to_list(uploads))

  def insert_previews_for_list_of_uploads([]), do: {:ok, MapSet.new}

  def insert_previews_for_list_of_uploads(uploads) do
    # NOTE: assuming all uploads are for the same event
    event = uploads
            |> List.first()
            |> find_event()

    multi = Multi.new
            |> Multi.delete_all(:delete,
                                from(p in Feeds.Preview,
                                     where: p.event_id == ^event.id))

    case insert_previews_for_uploads(multi, uploads) do
      {:ok, results} ->
        {:ok, for {{:preview, _}, preview} <- results, into: MapSet.new do
          preview
        end}
      {:error, error} ->
        Logger.error "Database error when inserting previews: #{inspect error}"
        {:error, :insert_previews_failed}
      {:error, name, error, results} ->
        Logger.error "Database error when inserting previews: #{inspect name} | #{inspect error}"
        Logger.error inspect(results)
        {:error, :insert_previews_failed}
    end
  end

  defp find_event(%RemoteStorage.Upload{file: %ExportedFile{download: %Download{event: %Feeds.Event{} = event}}}),
    do: event

  def insert_previews_for_uploads(multi, []),
    do: Repo.transaction(multi)

  def insert_previews_for_uploads(multi, [upload | uploads]) do
    multi
    |> insert_preview_for_upload(upload)
    |> insert_previews_for_uploads(uploads)
  end

  def insert_preview_for_upload(multi, upload) do
    multi
    |> Multi.insert({:preview, upload.file.uuid}, changeset(upload))
  end

  @spec changeset(RemoteStorage.Upload.t) :: Ecto.Changeset.t
  defp changeset(%RemoteStorage.Upload{file: file}) do
    %{
      name: Map.get(file.meta, :name, "Untitled"),
      width: file.meta.width,
      height: file.meta.height,
      path: ExportedFile.remote_path(file),
      sizes: ["1x"]
    }
    |> Feeds.Preview.changeset(event: file.download.event)
  end
end
