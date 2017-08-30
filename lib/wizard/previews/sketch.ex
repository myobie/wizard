defmodule Wizard.Previews.Sketch do
  require Logger
  alias Wizard.Previews.Sketch.Artboard
  alias Wizard.Previews.{Download, ExportedFile}

  @type artboards_result :: {:ok, list(Artboard.t)} |
                            {:error, :artboard_failed_to_parse |
                                     :artboards_json_failed_to_parse |
                                     :sketchtool_command_failed}

  @command "sketchtool"
  @export_args ~w|export artboards --background='#ffffff' -f png --save-for-web --overwriting --use-id-for-name|
  @list_args ~w|list artboards|

  @spec export(Download.t) :: {:ok, list(ExportedFile.t)} | {:error, atom}
  def export(download) do
    with {:ok, exported_files} <- export_artboards(download),
         {:ok, artboards} <- list_artboards(download)
    do
      {:ok, matchup(exported_files, artboards, download)}
    end
  end

  defp matchup(exported_files, artboards, %Download{} = download),
    do: matchup([], exported_files, artboards, download)

  defp matchup(result, _exported_files, [], %Download{} = _download), do: result

  defp matchup(result, exported_files, [board | artboards], %Download{} = download) do
     case Enum.find(exported_files, fn {uuid, _, _} -> board.id == uuid end) do
       {uuid, name, path} ->
         file = %ExportedFile{uuid: uuid, name: name, path: path, download: download, meta: board}
         matchup([file | result], exported_files, artboards, download)
       nil ->
         Logger.error "cannot find exported file for artboard listed in sketchtool's output: #{inspect board} – #{inspect exported_files}"
         matchup(result, exported_files, artboards, download)
     end
  end

  @spec installed?() :: boolean
  def installed? do
    case cmd("which", [@command]) do
      {_, 0} -> true
      _ -> false
    end
  end

  def cmd(command, args, opts \\ []) do
    Logger.debug "&&&&&&&&&"
    Logger.debug "$ #{command} #{Enum.join(args, " ")}"
    Logger.debug "&&&&&&&&&"
    # System.cmd command, args, opts

    command_string = Enum.join([command] ++ args, " ")

    settings = cmd_settings(opts)

    Port.open({:spawn, command_string}, settings)
    |> receive_data()
  end

  defp cmd_settings([]) do
    [:stream, :in, :eof, :hide, :exit_status]
  end

  defp cmd_settings(opts) do
    case Keyword.fetch(opts, :cd) do
      {:ok, dir} ->
        cmd_settings([]) ++ [{:cd, dir}]
      _ ->
        cmd_settings([])
    end
  end

  defp receive_data(port), do: receive_data(port, [])
  defp receive_data(port, acc) do
    receive do
      {^port, {:data, bytes}} ->
        receive_data(port, [acc | bytes])
      {^port, :eof} ->
        send(port, {self(), :close})
        receive do
          {^port, :closed} -> true
        end
        exit_code = receive do
          {^port, {:exit_status, code}} -> code
        end
        {to_string(List.flatten(acc)), exit_code}
    end
  end

  @spec export_artboards(Download.t) :: {:ok, list({String.t, String.t, String.t})} | {:error, :sketchtool_command_failed}
  def export_artboards(download) do
    dir_path = dir(download.path)
    case cmd(@command, args(:export, download.path), cd: dir_path) do
      {output, 0} -> {:ok, parse_exported_filenames(output, dir_path)}
      {message, code} ->
        Logger.error "sketchtool command failed with status #{code} and message: #{message}"
        {:error, :sketchtool_command_failed}
    end
  end

  @spec parse_exported_filenames(String.t, String.t) :: list({String.t, String.t, String.t})
  def parse_exported_filenames(output, dir_path) do
    for line <- lines(output) do
      filename = parse_filename(line)
      uuid = parse_uuid(filename)
      {uuid, filename, dir_path}
    end
  end

  @spec lines(binary) :: list(String.t)
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

  @spec list_artboards(Download.t) :: artboards_result
  def list_artboards(download) do
    case cmd(@command, args(:list, download.path), cd: dir(download.path)) do
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
  def args(:export, file),
    do: @export_args ++ ["'#{file}'"]

  def args(:list, file),
    do: @list_args ++ ["'#{file}'"]
end
