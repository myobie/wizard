defmodule Wizard.Sharepoint.Api.Sites do
  alias Wizard.Sharepoint.Api

  def search(service, query) do
    params = URI.encode_query(%{search: query})
    uri = URI.parse("#{service.endpoint_uri}/v2.0/sites")
    url = to_string(%{uri | query: params})

    resp = Api.get(url, service.authorization.access_token)

    Enum.map(resp["value"], fn site -> %{
      remote_id: site["id"],
      hostname: site["siteCollection"]["hostName"],
      title: site["title"],
      url: site["webUrl"],
      description: site["description"]
    } end)
  end

  def drives(site) do
    url = "#{site.service.endpoint_uri}/v2.0/sites/#{site.remote_id}/drives"

    resp = Api.get(url, site.service.authorization.access_token)

    Enum.map(resp["value"], fn drive -> %{
      remote_id: drive["id"],
      url: drive["webUrl"],
      name: drive["name"],
      description: drive["description"],
      type: drive["driveType"]
    } end)
  end
end
