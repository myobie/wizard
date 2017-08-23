defmodule Wizard.Previews.Downloader do
  require Logger
  alias Wizard.{Feeds, Repo, Sharepoint, Subscriber}
  alias Wizard.Previews.Download

  @spec download(Feeds.Event.t) :: {:ok, Download.t} | {:error, atom}
  def download(%Feeds.Event{subject: nil} = event) do
    event
    |> Feeds.preload_event_subject()
    |> download()
  end

  def download(%Feeds.Event{subject: %Sharepoint.Item{} = item} = event) do
    item = Repo.preload(item, drive: [:subscription, site: :service])

    with url = download_url(item),
      auth = Subscriber.find_authorization(item.drive.subscription),
      {:ok, dir_path} <- tmpdir(),
      path = Path.join(dir_path, item.name),
      :ok <- clear(path),
      :ok <- Sharepoint.Api.download(url, to: path, access_token: auth.access_token)
    do
      {:ok, %Download{url: url, path: path, event: event}}
    end
  end

  def download(%Feeds.Event{}),
    do: {:error, :unkown_event_subject_type}

  @spec download_url(Sharepoint.Item.t) :: String.t
  defp download_url(%Sharepoint.Item{remote_id: item_id, drive: %{remote_id: drive_id, site: %{service: %{endpoint_uri: endpoint_uri}}}}) do
    "#{endpoint_uri}/v2.0/drives/#{drive_id}/items/#{item_id}/content"
  end

  @spec clear(Path.t) :: :ok | {:error, atom}
  defp clear(path) do
    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      error -> error
    end
  end

  @spec tmpdir() :: {:ok, Path.t} | {:error, atom}
  defp tmpdir do
    case System.tmp_dir() do
      nil -> {:error, :not_writable}
      dir ->
        full_dir = Path.join([dir, "wizard", SecureRandom.hex()])
        case File.mkdir_p(full_dir) do
          :ok ->
            {:ok, full_dir}
          error ->
            Logger.error "tmp_dir() failed: #{inspect error}"
            error
        end
    end
  end
end
