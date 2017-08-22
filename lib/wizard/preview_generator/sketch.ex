defmodule Wizard.PreviewGenerator.Sketch.Artboard do
  defstruct id: "", name: "", width: 0, height: 0
  @type t :: %__MODULE__{}
end

defmodule Wizard.PreviewGenerator.Sketch do
  require Logger
  alias Wizard.PreviewGenerator.Sketch.Artboard
  alias Wizard.PreviewGenerator.ExportedFile
  alias Wizard.Feeds.Event

  @type artboards_result :: {:ok, list(Artboard.t)} |
                            {:error, :artboard_failed_to_parse |
                                     :artboards_json_failed_to_parse |
                                     :sketchtool_command_failed}

  @command "sketchtool"
  @export_args ~w|export artboards --background='rgb(255,255,255)' --overwriting --use-id-for-name|
  @list_args ~w|list artboards|

  @spec export(Path.t, Event.t) :: {:ok, list(ExportedFile.t)} | {:error, atom}
  def export(path, event) do
    with {:ok, exported_files} <- export_artboards(path, event),
         {:ok, artboards} <- list_artboards(path) do
      {:ok, for file <- exported_files do
        artboard = Enum.find(artboards, fn board -> board.id == file.uuid end)
        %{file | meta: artboard}
      end}
    end
  end

  @spec installed?() :: boolean
  def installed? do
    case System.cmd("which", [@command]) do
      {_, 0} -> true
      _ -> false
    end
  end

  @spec export_artboards(Path.t, Event.t) :: {:ok, list(ExportedFile.t)} | {:error, :sketchtool_command_failed}
  def export_artboards(file, event) do
    dir_path = dir(file)
    case System.cmd(@command, args(:export, file), cd: dir_path) do
      {output, 0} -> {:ok, parse_exported_filenames(output, dir_path, event)}
      {message, code} ->
        Logger.error "sketchtool command failed with status #{code} and message: #{message}"
        {:error, :sketchtool_command_failed}
    end
  end

  @spec parse_exported_filenames(String.t, String.t, Event.t) :: list(ExportedFile.t)
  def parse_exported_filenames(output, dir_path, event) do
    for line <- lines(output) do
      filename = parse_filename(line)
      uuid = parse_uuid(filename)
      %ExportedFile{uuid: uuid, name: filename, path: dir_path, event: event}
    end
  end

  @spec lines(String.t) :: list(String.t)
  defp lines(string) do
    string
    |> String.trim()
    |> String.split("\n")
  end

  @spec parse_filename(String.t) :: String.t
  defp parse_filename("Exported " <> name), do: name
  defp parse_filename(string), do: string

  @spec parse_uuid(String.t) :: String.t
  defp parse_uuid(<<id :: binary-size(36)>> <> ".png"), do: to_string(id)
  defp parse_uuid(string), do: string

  @spec list_artboards(Path.t) :: artboards_result
  def list_artboards(file) do
    case System.cmd(@command, args(:list, file), cd: dir(file)) do
      {json, 0} -> parse_artboards_json(json)
      {message, code} ->
        Logger.error "sketchtool command failed with status #{code} and message: #{message}"
        {:error, :sketchtool_command_failed}
    end
  end

  @spec parse_artboards_json(String.t) :: artboards_result
  defp parse_artboards_json(string) do
    case Poison.decode(string) do
      {:ok, %{"pages" => pages}} -> parse_pages(pages)
      {:error, _} -> {:error, :artboards_json_failed_to_parse}
    end
  end

  @spec parse_pages(list(map)) :: artboards_result
  defp parse_pages(pages),
    do: parse_pages([], pages)

  @spec parse_pages(list(Artboard.t), list(map)) :: artboards_result
  defp parse_pages(result, []), do: {:ok, result}
  defp parse_pages(result, [page | pages]) do
    with {:ok, artboards} <- parse_artboards(page) do
      result ++ artboards
      |> parse_pages(pages)
    end
  end

  @spec parse_artboards(list(map)) :: artboards_result
  defp parse_artboards(%{"artboards" => artboards}),
    do: parse_artboards([], artboards)

  defp parse_artboards(_), do: {:error, :artboard_failed_to_parse}

  @spec parse_artboards(list(Artboard.t), list(map)) :: artboards_result
  defp parse_artboards(result, []), do: {:ok, result}
  defp parse_artboards(result, [info | artboards]) do
    with {:ok, artboard} <- parse_artboard(info) do
      [artboard | result]
      |> parse_artboards(artboards)
    end
  end

  @spec parse_artboard(map) :: {:ok, Artboard.t} | {:error, :artboard_failed_to_parse}
  defp parse_artboard(%{"id" => id, "name" => name, "rect" => %{"width" => width, "height" => height}}) do
    name = name
           |> String.trim()
           |> String.replace("/", "-")

    {:ok, %Artboard{
      id: id,
      name: name,
      width: width,
      height: height
    }}
  end
  defp parse_artboard(_), do: {:error, :artboard_failed_to_parse}

  @spec dir(String.t) :: String.t
  defp dir(file),
    do: Path.dirname(file)

  @spec args(:export | :list, String.t) :: list
  defp args(:export, file),
    do: @export_args ++ [file]

  defp args(:list, file),
    do: @list_args ++ [file]
end
