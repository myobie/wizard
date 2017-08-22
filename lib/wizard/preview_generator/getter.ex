defmodule Wizard.PreviewGenerator.Getter do
  require Logger
  alias Wizard.PreviewGenerator.RemoteStorage
  alias Wizard.Feeds.Preview

  def get_preview(%Preview{} = preview),
    do: get_preview(preview, "1x")

  def get_preview(%Preview{} = preview, size) do
    uri = RemoteStorage.get_uri(preview.path, size)

    Logger.debug "getting preview #{preview.path}"

    case HTTPoison.get(to_string(uri)) do
      {:ok, %{status_code: 200, body: body, headers: headers}} ->
        content_type = Enum.find_value(headers, "application/octet-stream", fn {name, value} ->
          if name == "content-type", do: value
        end)
        {:ok, %{body: body, content_type: content_type}}
      {:error, error} ->
        Logger.error "Error getting blob from remote storage #{inspect error}"
        {:error, :get_preview_failed}
    end
  end
end
