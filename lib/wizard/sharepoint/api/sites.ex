defmodule Wizard.Sharepoint.Api.Sites do
  alias Wizard.Sharepoint.{Api, Authorization, Service, Site}

  @spec search(Authorization.t, Service.t, String.t) :: [map]
  def search(authorization, service, query) do
    params = URI.encode_query(%{search: query})
    uri = URI.parse("#{service.endpoint_uri}/v2.0/sites")
    url = to_string(%{uri | query: params})

    case Api.get(url, authorization.access_token) do
      {:ok, %{"value" => value}} -> process_sites(value)
      _ -> []
    end
  end

  # TODO: switch to structs so we have better guaruntees
  @spec process_sites([map]) :: [map]
  defp process_sites(sites_info) do
    Enum.map(sites_info, fn site -> %{
      remote_id: site["id"],
      hostname: get_in(site, ["siteCollection", "hostName"]),
      title: site["title"],
      url: site["webUrl"],
      description: site["description"]
    } end)
  end

  @spec drives(Authorization.t, Site.t) :: [map]
  def drives(authorization, site) do
    url = "#{site.service.endpoint_uri}/v2.0/sites/#{site.remote_id}/drives"

    case Api.get(url, authorization.access_token) do
      {:ok, %{"value" => value}} -> process_drives(value)
      _ -> []
    end
  end

  # TODO: switch to structs so we have better guaruntees
  @spec process_drives([map]) :: [map]
  defp process_drives(drives_info) do
    Enum.map(drives_info, fn drive -> %{
      remote_id: drive["id"],
      url: drive["webUrl"],
      name: drive["name"],
      description: drive["description"],
      type: drive["driveType"]
    } end)
  end
end
