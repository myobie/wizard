defmodule Wizard.PreviewGenerator.Previews do
  require Logger
  alias Wizard.Repo
  alias Ecto.Multi
  alias Wizard.Feeds.Preview
  alias Wizard.PreviewGenerator.ExportedFile

  @spec insert_previews_for_files(list(ExportedFile.t)) :: {:ok, list(ExportedFile.t)} | {:error, atom}
  def insert_previews_for_files(files) do
    case insert_previews_for_files(Multi.new, files) do
      {:ok, results} ->
        {:ok, for {{:preview, uuid}, preview} <- results do
          file = Enum.find(files, fn f -> f.uuid == uuid end)
          %{file | preview: preview}
        end}
      {:error, error} ->
        Logger.error "Database error when inserting previews: #{inspect error}"
        {:error, :insert_previews_failed}
      {:error, name, error, results} ->
        Logger.error "Database error when inserting previews: #{name} | #{inspect error}"
        Logger.error inspect(results)
        {:error, :insert_previews_failed}
    end
  end

  def insert_previews_for_files(multi, []),
    do: Repo.transaction(multi)

  def insert_previews_for_files(multi, [file | files]) do
    multi
    |> insert_preview_for_file(file)
    |> insert_previews_for_files(files)
  end

  def insert_preview_for_file(multi, file) do
    multi
    |> Multi.insert({:preview, file.uuid}, changeset(file))
  end

  @spec changeset(ExportedFile.t) :: Ecto.Changeset.t
  defp changeset(file) do
    %{
      name: file.meta.name,
      width: file.meta.width,
      height: file.meta.height,
      path: ExportedFile.remote_path(file),
      sizes: ["1x"]
    }
    |> Preview.changeset(event: file.event)
  end
end
