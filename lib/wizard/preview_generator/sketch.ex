defmodule Wizard.PreviewGenerator.Sketch.Artboard do
  defstruct id: "", name: "", width: 0, height: 0
end

defmodule Wizard.PreviewGenerator.Sketch do
  alias Wizard.PreviewGenerator.Sketch.Artboard

  @command "sketchtool"
  @export_args ~w|export artboards --background='rgb(255,255,255)' --overwriting --use-id-for-name|
  @list_args ~w|list artboards|

  def export(file) do
    with {:ok, png_map} <- export_artboards(file),
         {:ok, artboards} <- list_artboards(file) do
      {:ok, for artboard <- artboards, into: %{} do
        {Map.get(png_map, artboard.id), artboard}
      end}
    end
  end

  def installed? do
    case System.cmd("which", [@command]) do
      {_, 0} -> true
      _ -> false
    end
  end

  def export_artboards(file) do
    case System.cmd(@command, args(:export, file), cd: dir(file)) do
      {output, 0} -> {:ok, parse_exported_filenames(output)}
      {message, code} -> {:error, {message, code}}
    end
  end

  def parse_exported_filenames(output) do
    for line <- lines(output), into: %{} do
      filename = parse_filename(line)
      uuid = parse_uuid(filename)
      {uuid, filename}
    end
  end

  defp lines(string) do
    string
    |> String.trim()
    |> String.split("\n")
  end

  defp parse_filename("Exported " <> name), do: name
  defp parse_filename(string), do: string

  defp parse_uuid(<<id :: binary-size(36)>> <> ".png"), do: to_string(id)
  defp parse_uuid(string), do: string

  def list_artboards(file) do
    case System.cmd(@command, args(:list, file), cd: dir(file)) do
      {json, 0} -> parse_artboards_json(json)
      {message, code} -> {:error, {message, code}}
    end
  end

  defp parse_artboards_json(string) do
    case Poison.decode(string) do
      {:ok, %{"pages" => pages}} -> parse_pages(pages)
      {:error, _} -> {:error, :json_failed_to_parse}
    end
  end

  defp parse_pages(pages),
    do: parse_pages([], pages)

  defp parse_pages(result, []), do: {:ok, result}
  defp parse_pages(result, [page | pages]) do
    case parse_artboards(page) do
      {:ok, artboards} ->
        result ++ artboards
        |> parse_pages(pages)
      error ->
        error
    end
  end

  defp parse_artboards(%{"artboards" => artboards}),
    do: parse_artboards([], artboards)

  defp parse_artboards(_), do: []

  defp parse_artboards(result, []), do: {:ok, result}
  defp parse_artboards(result, [info | artboards]) do
    case parse_artboard(info) do
      %Artboard{} = artboard ->
        [artboard | result]
        |> parse_artboards(artboards)
      error ->
        error
    end
  end

  defp parse_artboard(%{"id" => id, "name" => name, "rect" => %{"width" => width, "height" => height}}) do
    %Artboard{
      id: id,
      name: name,
      width: width,
      height: height
    }
  end
  defp parse_artboard(_), do: {:error, :artboard_failed_to_parse}

  defp dir(file),
    do: Path.dirname(file)

  defp args(:export, file),
    do: @export_args ++ [file]

  defp args(:list, file),
    do: @list_args ++ [file]
end
