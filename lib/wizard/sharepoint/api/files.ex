defmodule Wizard.Sharepoint.Api.Files do
  alias Wizard.Sharepoint.{Api, Drive}

  @spec next(String.t, [access_token: String.t]) :: Api.result
  def next(url, [access_token: access_token]) do
    url
    |> Api.client.get(access_token: access_token)
  end

  @spec delta(Drive.t, [access_token: String.t]) :: Api.result
  def delta(%Drive{} = drive, [access_token: access_token]) do
    initial_delta_url(drive)
    |> Api.client.get(access_token: access_token)
  end

  @spec initial_delta_url(Drive.t) :: String.t
  defp initial_delta_url(%Drive{remote_id: drive_id, site: %{service: %{endpoint_uri: endpoint_uri}}}) do
    "#{endpoint_uri}/v2.0/drives/#{drive_id}/root:/:/delta"
  end
end
