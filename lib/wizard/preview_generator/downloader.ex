defmodule Wizard.PreviewGenerator.Downloader do
  alias Wizard.{Repo, User}
  alias Wizard.Sharepoint.{Api, Authorization, Item, Service}

  @spec download_url(Item.t) :: String.t
  def download_url(%Item{remote_id: item_id, drive: %{remote_id: drive_id, site: %{service: %{endpoint_uri: endpoint_uri}}}}) do
    "#{endpoint_uri}/v2.0/drives/#{drive_id}/items/#{item_id}/content"
  end

  def download(%Item{} = item, %User{} = user) do
    with item <- Repo.preload(item, drive: [site: :service]),
         url <- download_url(item),
         {:ok, auth} <- find_authorization(item.drive.site.service, user),
         {:ok, dir_path} <- tmpdir(),
         path <- Path.join(dir_path, item.name),
     do: Api.download(url, to: path, access_token: auth.access_token)
  end

  @spec tmpdir() :: {:ok, Path.t} | {:error, any}
  defp tmpdir do
    case System.tmp_dir() do
      nil -> {:error, :not_writable}
      dir ->
        {:ok, Path.join(dir, "downloads")}
    end
  end

  defp find_authorization(%Service{} = service, %User{} = user) do
    case Repo.get_by(Authorization, service_id: service.id, user_id: user.id) do
      nil -> {:error, :authorization_not_found}
      auth -> {:ok, auth}
    end
  end
end
