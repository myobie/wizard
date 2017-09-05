defmodule Wizard.Sharepoint.Api.Files do
  alias Wizard.Sharepoint.{Api, Drive}

  @spec get_item(String.t | map, Drive.t, Api.access) :: Api.result
  def get_item(id, %Drive{} = drive, [access_token: access_token]) when is_binary(id) do
    item_url(id, drive)
    |> Api.client.get(access_token: access_token)
  end

  def get_item(%{"id" => id}, %Drive{} = drive, [access_token: access_token]),
    do: get_item(id, drive, access_token: access_token)

  @spec item_url(String.t, Drive.t) :: String.t
  defp item_url(id, drive),
    do: "#{drive_url(drive)}/items/#{id}"

  def get_items(items, drive, [access_token: access_token]) do
    items = items
            |> Flow.from_enumerable()
            |> Flow.map(fn item ->
              case get_item(item, drive, access_token: access_token) do
                {:ok, full_item} -> full_item
                error -> error
              end
            end)
            |> Enum.to_list()

    if Enum.any?(items, &(match?({:error, _}, &1))) do
      {:error, {:get_items_failed, items}}
    else
      {:ok, items}
    end
  end

  @spec next(String.t, Api.access) :: Api.result
  def next(url, [access_token: access_token]) do
    url
    |> Api.client.get(access_token: access_token)
  end

  @spec delta(Drive.t, Api.access) :: Api.result
  def delta(%Drive{} = drive, [access_token: access_token]) do
    initial_delta_url(drive)
    |> Api.client.get(access_token: access_token)
  end

  @spec initial_delta_url(Drive.t) :: String.t
  defp initial_delta_url(drive) do
    "#{drive_url(drive)}/root:/:/delta"
  end

  @spec drive_url(Drive.t) :: String.t
  defp drive_url(%Drive{remote_id: drive_id,
                        site: %{service: %{endpoint_uri: endpoint_uri}}})
  do
    "#{endpoint_uri}/v2.0/drives/#{drive_id}"
  end
end
