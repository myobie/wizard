defmodule Wizard.PreviewGenerator.Downloader.Download do
  defstruct url: "", path: ""
  @type t :: %__MODULE__{}
end

defmodule Wizard.PreviewGenerator.Downloader do
  require Logger
  alias Wizard.{Repo, User}
  alias Wizard.Sharepoint.{Api, Authorization, Item, Service}
  alias Wizard.PreviewGenerator.Downloader.Download

  @spec download_url(Item.t) :: String.t
  def download_url(%Item{remote_id: item_id, drive: %{remote_id: drive_id, site: %{service: %{endpoint_uri: endpoint_uri}}}}) do
    "#{endpoint_uri}/v2.0/drives/#{drive_id}/items/#{item_id}/content"
  end

  @spec download(Item.t, User.t) :: {:ok, Download.t} | {:error, atom}
  def download(%Item{} = item, %User{} = user) do
    with item = Repo.preload(item, drive: [site: :service]),
         url = download_url(item),
         {:ok, auth} <- find_authorization(item.drive.site.service, user),
         {:ok, dir_path} <- tmpdir(),
         path = Path.join(dir_path, item.name),
         :ok <- clear(path),
         :ok <- Api.download(url, to: path, access_token: auth.access_token),
     do: {:ok, %Download{url: url, path: path}}
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

  @spec find_authorization(Service.t, User.t) :: {:ok, Authorization.t} | {:error, :authorization_not_found}
  defp find_authorization(%Service{} = service, %User{} = user) do
    case Repo.get_by(Authorization, service_id: service.id, user_id: user.id) do
      nil -> {:error, :authorization_not_found}
      auth -> {:ok, auth}
    end
  end
end
