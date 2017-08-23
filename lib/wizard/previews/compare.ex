defmodule Wizard.Previews.Compare do
  require Logger
  import Ecto.Query
  alias Wizard.{Feeds, RemoteStorage, Repo}
  alias Wizard.Previews.{ExportedFile, PNG}

  @spec filter_unchanged_exports(list(ExportedFile.t)) :: {:ok, list(ExportedFile.t)} | {:error, atom}
  def filter_unchanged_exports(files) do
    files
    |> Flow.from_enumerable()
    |> Flow.filter(&filter_file/1)
    |> Enum.to_list()
  end

  @spec filter_file(ExportedFile.t) :: boolean
  defp filter_file(file) do
    with {:ok, preview} <- find_last_preview_for_file(file),
      {:ok, old_png} <- RemoteStorage.get_preview(preview),
      {:ok, new_png} <- PNG.read(Path.join(file.path, file.name))
    do
      is_same_png?(old_png, new_png)
    else
      {:error, :not_found} -> true
      {:error, error} ->
        Logger.error "Error filtering file #{inspect error} – #{inspect file}"
        # NOTE: may want to raise here so the Task is aborted and we try again later
        true
    end
  end

  defp find_last_preview_for_file(%ExportedFile{download: %{event: event}} = file) do
    path = ExportedFile.remote_path(file)

    case last_preview(event.subject_id, event.subject_type, path) do
      nil -> {:error, :not_found}
      preview -> {:ok, preview}
    end
  end

  defp last_preview(subject_id, subject_type, path) do
    last_preview_query(subject_id, subject_type, path)
    |> Repo.one()
  end

  defp last_preview_query(subject_id, subject_type, path) do
    from(p in Feeds.Preview,
      select: p,
      join: e in assoc(p, :event),
      where: e.subject_id == ^subject_id,
      where: e.subject_type == ^subject_type,
      where: p.path == ^path,
      order_by: [desc: p.id],
      limit: 1)
  end

  @spec is_same_png?(PNG.t, PNG.t) :: boolean
  def is_same_png?(png1, png2) do
    is_same_size?(png1.image, png2.image) &&
      is_same_bit_depth?(png1.image, png2.image) &&
      has_same_pixels?(png1.image, png2.image)
  end

  defp is_same_size?(png1, png2),
    do: png1.width == png2.width && png1.height == png2.height

  defp is_same_bit_depth?(png1, png2),
    do: png1.bit_depth == png2.bit_depth

  defp has_same_pixels?(png1, png2),
    do: png1.pixels == png2.pixels
end
