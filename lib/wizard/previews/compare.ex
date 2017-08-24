defmodule Wizard.Previews.Compare do
  require Logger
  import Ecto.Query
  alias Wizard.{Feeds, RemoteStorage, Repo}
  alias Wizard.Previews.{ExportedFile, PNG}

  @spec filter_unchanged_exports(list(ExportedFile.t)) :: {:ok, list(ExportedFile.t)} | {:error, atom}
  def filter_unchanged_exports(files) do
    start_size = length(files)

    files = files
             |> Flow.from_enumerable()
             |> Flow.filter(&filter_file/1)
             |> Enum.to_list()

    final_size = length(files)

    if final_size < start_size do
      Logger.debug "Only keeping #{final_size} of #{start_size} files"
    else
      Logger.debug "No files were filtered out"
    end

    {:ok, files}
  end

  @spec filter_file(ExportedFile.t) :: boolean
  defp filter_file(file) do
    with {:ok, preview} <- find_last_preview_for_file(file),
      {:ok, old_png} <- RemoteStorage.get_preview(preview),
      {:ok, new_png} <- PNG.read(Path.join(file.path, file.name))
    do
      not is_same_png?(old_png, new_png)
    else
      {:error, :not_found} ->
        Logger.error "No old preview was found for #{inspect file}"
        true
      {:error, error} ->
        Logger.error "Error filtering file #{inspect error} – #{inspect file}"
        # NOTE: may want to raise here so the Task is aborted and we try again later
        true
    end
  end

  defp find_last_preview_for_file(%ExportedFile{download: %{event: event}} = file) do
    case last_preview(event, file.meta.name) do
      nil -> {:error, :not_found}
      preview -> {:ok, preview}
    end
  end

  defp last_preview(event, name) do
    last_preview_query(event, name)
    |> Repo.one()
  end

  defp last_preview_query(event, name) do
    from(p in Feeds.Preview,
      select: p,
      join: e in assoc(p, :event),
      where: e.id < ^event.id,
      where: e.subject_id == ^event.subject_id,
      where: e.subject_type == ^event.subject_type,
      where: p.name == ^name,
      order_by: [desc: e.id],
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
