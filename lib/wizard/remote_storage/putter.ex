defmodule Wizard.RemoteStorage.Putter do
  require Logger
  alias Wizard.RemoteStorage
  alias Wizard.Previews.ExportedFile

  @png_blob_headers %{"Content-type" => "image/png",
                      "x-ms-blob-type" => "BlockBlob"}

  @spec put_exported_files(list(ExportedFile.t)) :: {:ok, list(ExportedFile.t)} | {:error, atom}
  def put_exported_files(files),
    do: put_exported_files([], files)

  @spec put_exported_files(list(ExportedFile.t), list(ExportedFile.t)) :: {:ok, list(ExportedFile.t)} | {:error, atom}
  def put_exported_files(result, []), do: {:ok, result}

  def put_exported_files(result, [file | files]) do
    case put_exported_file(file) do
      {:ok, file} ->
        [file | result]
        |> put_exported_files(files)
      {:error, :put_request_failed} ->
        {:error, :put_failed}
    end
  end

  @spec put_exported_file(ExportedFile.t) :: {:ok, ExportedFile.t} | {:error, :put_request_failed}
  def put_exported_file(file) do
    uri = ExportedFile.remote_path(file)
          |> RemoteStorage.put_uri("1x")

    file = %{file | put_uri: uri}

    case request(file) do
      {:ok, %HTTPoison.Response{status_code: 201}} ->
        {:ok, file}
      {:error, response} ->
        Logger.error "put request failed #{inspect response}"
        Logger.error inspect(file)
        {:error, :put_request_failed}
    end
  end

  @spec request(ExportedFile.t) :: {:ok, HTTPoison.Response.t} | {:error, HTTPoison.Error.t}
  defp request(%ExportedFile{put_uri: url, name: name, path: path}),
    do: request(to_string(url), Path.join(path, name))

  @spec request(String.t, String.t) :: {:ok, HTTPoison.Response.t} | {:error, HTTPoison.Error.t}
  defp request(url, local_path) do
    HTTPoison.put(url, {:file, local_path}, @png_blob_headers)
  end
end
