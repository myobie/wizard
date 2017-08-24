defmodule Wizard.RemoteStorage.Getter do
  require Logger
  alias Wizard.Feeds.Preview
  alias Wizard.RemoteStorage
  alias Wizard.Previews.PNG

  @default_size "1x"

  @spec get_preview(Preview.t, String.t) :: {:ok, PNG.t} | {:error, :get_preview_failed}
  def get_preview(%Preview{} = preview, size \\ @default_size) do
    case get_preview_raw_data(preview, size) do
      {:ok, data} ->
        PNG.from_binary(data, name: preview.name)
      {:error, error} ->
        {:error, error}
    end
  end

  @spec get_preview_raw_data(Preview.t, String.t) :: {:ok, binary} | {:error, :get_preview_failed}
  def get_preview_raw_data(%Preview{} = preview, size \\ @default_size) do
    uri = RemoteStorage.get_uri(preview.path, size)

    Logger.debug "getting preview #{preview.path}"

    case HTTPoison.get(to_string(uri)) do
      {:ok, %{status_code: 200, body: body, headers: headers}} ->
        case content_type(headers) do
          "image/png" ->
            {:ok, body}
          _ ->
            {:error, :unknown_preview_file_type}
        end
      {:error, error} ->
        Logger.error "Error getting blob from remote storage #{inspect error}"
        {:error, :get_preview_failed}
    end
  end

  @spec download_preview(Preview.t, String.t, [to: Path.t]) :: {:ok, Path.t} | {:error, atom}
  def download_preview(preview, size \\ @default_size, [to: path]) do
    with {:ok, png} <- get_preview(preview, size),
      {:ok, _} <- PNG.write(png, to: path),
      full_path = PNG.full_path(path, png)
    do
      {:ok, full_path}
    end
  end

  defp content_type(headers) do
    Enum.find_value(headers, "application/octet-stream", fn {name, value} ->
      if name == "Content-Type", do: value
    end)
  end

end
