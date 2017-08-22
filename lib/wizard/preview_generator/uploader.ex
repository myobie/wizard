defmodule Wizard.PreviewGenerator.Uploader do
  require Logger
  alias Wizard.PreviewGenerator.{ExportedFile, RemoteStorage}

  @png_blob_headers %{"Content-type" => "image/png",
                      "x-ms-blob-type" => "BlockBlob"}

  @spec upload_exported_files(list(ExportedFile.t)) :: {:ok, list(ExportedFile.t)} | {:error, atom}
  def upload_exported_files(files),
    do: upload_exported_files([], files)

  @spec upload_exported_files(list(ExportedFile.t), list(ExportedFile.t)) :: {:ok, list(ExportedFile.t)} | {:error, atom}
  def upload_exported_files(result, []), do: {:ok, result}

  def upload_exported_files(result, [file | files]) do
    case upload_exported_file(file) do
      {:ok, file} ->
        [file | result]
        |> upload_exported_files(files)
      {:error, :upload_request_failed} ->
        {:error, :upload_failed}
    end
  end

  @spec upload_exported_file(ExportedFile.t) :: {:ok, ExportedFile.t} | {:error, :upload_request_failed}
  def upload_exported_file(file) do
    uri = ExportedFile.remote_path(file)
          |> RemoteStorage.upload_uri("1x")

    file = %{file | upload_uri: uri}

    case request(file) do
      {:ok, %HTTPoison.Response{status_code: 201}} ->
        {:ok, file}
      {:error, response} ->
        Logger.error "Upload request failed #{inspect response}"
        Logger.error inspect(file)
        {:error, :upload_request_failed}
    end
  end

  @spec request(ExportedFile.t) :: {:ok, HTTPoison.Response.t} | {:error, HTTPoison.Error.t}
  defp request(%ExportedFile{upload_uri: url, name: name, path: path}),
    do: request(to_string(url), Path.join(path, name))

  @spec request(String.t, String.t) :: {:ok, HTTPoison.Response.t} | {:error, HTTPoison.Error.t}
  defp request(url, local_path) do
    HTTPoison.put(url, {:file, local_path}, @png_blob_headers)
  end
end
