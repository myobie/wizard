defmodule Wizard.RemoteStorage.Putter do
  require Logger
  alias Wizard.RemoteStorage
  alias Wizard.RemoteStorage.Upload
  alias Wizard.Previews.ExportedFile

  @png_blob_headers %{"Content-type" => "image/png",
                      "x-ms-blob-type" => "BlockBlob"}

  @spec put_exported_files(MapSet.t(ExportedFile.t)) :: {:ok, MapSet.t(Upload.t)} | {:error, atom}
  def put_exported_files(files),
    do: put_exported_files(MapSet.new, Enum.to_list(files))

  @spec put_exported_files(MapSet.t(Upload.t), list(ExportedFile.t)) :: {:ok, MapSet.t(Upload.t)} | {:error, atom}
  def put_exported_files(result, []), do: {:ok, result}

  def put_exported_files(result, [file | files]) do
    case put_exported_file(file) do
      {:ok, file} ->
        MapSet.put(result, file)
        |> put_exported_files(files)
      {:error, :put_request_failed} ->
        {:error, :put_failed}
    end
  end

  @spec put_exported_file(ExportedFile.t) :: {:ok, Upload.t} | {:error, :put_request_failed}
  def put_exported_file(file) do
    remote_path = ExportedFile.remote_path(file)
    local_path = Path.join(file.path, file.name)
    uri = RemoteStorage.put_uri(remote_path, "1x")

    case request(to_string(uri), local_path) do
      {:ok, %HTTPoison.Response{status_code: 201}} ->
        {:ok, %Upload{remote_path: remote_path, file: file}}
      {:ok, %HTTPoison.Response{status_code: code} = response} ->
        Logger.error "put request failed (#{code}) #{inspect response}"
        Logger.error inspect(file)
        {:error, :put_request_failed}
      {:error, response} ->
        Logger.error "put request failed #{inspect response}"
        Logger.error inspect(file)
        {:error, :put_request_failed}
    end
  end

  @spec request(String.t, Path.t) :: {:ok, HTTPoison.Response.t} | {:error, HTTPoison.Error.t}
  defp request(url, local_path) do
    HTTPoison.put(url, {:file, local_path}, @png_blob_headers)
  end
end
