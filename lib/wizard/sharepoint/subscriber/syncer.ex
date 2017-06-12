defmodule Wizard.Sharepoint.Subscriber.Syncer do
  alias Wizard.Repo
  alias Ecto.Multi
  alias Wizard.Sharepoint.Api
  alias Wizard.Sharepoint.{Authorization, Drive}

  use GenServer
  require Logger

  def init(%Drive{remote_id: drive_id, delta_link: delta_link, authorization: %Authorization{access_token: access_token, url: base_url}} = drive) do
    {:ok, %{
      drive: drive,
      base_url: base_url,
      delta_link: delta_link,
      next_link: nil,
      drive_id: drive_id,
      access_token: access_token
    }}
  end

  def start_link(drive) do
    drive = Repo.preload(drive, :authorization)
    GenServer.start_link(__MODULE__, drive, [])
  end

  def handle_cast(:sync, state) do
    {:ok, state} = fetch(state)
    {:stop, :normal, state}
  end

  defp fetch(%{base_url: base_url, drive_id: drive_id, access_token: access_token, delta_link: nil, next_link: nil} = state) do
    resp = Api.get("#{base_url}/v2.0/drives/#{drive_id}/root:/:/delta", access_token)
    process(resp, state)
  end

  defp fetch(%{access_token: access_token, next_link: next_link} = state) do
    resp = Api.get(next_link, access_token)
    process(resp, state)
  end

  defp fetch(%{access_token: access_token, delta_link: delta_link} = state) do
    resp = Api.get(delta_link, access_token)
    process(resp, state)
  end

  defp process(%{"@odata.deltaLink" => delta_link, "value" => items}, %{drive: drive} = state) do
    with {:ok, _} <- process_items(items, drive),
         {:ok, _} <- update_drive(drive, delta_link) do
      {:ok, state}
    end
  end

  defp process(%{"@odata.nextLink" => next_link, "value" => items}, %{drive: drive} = state) do
    with {:ok, _} <- process_items(items, drive) do
      fetch(%{state | next_link: next_link, delta_link: nil})
    end
  end

  defp process_items(items, drive) do
    Logger.debug("processing #{length(items)} items")
    multi = Enum.reduce(items, Multi.new, fn item, multi ->
      process_item(item, multi, drive)
    end)
    Repo.transaction(multi)
  end

  defp process_item(item, multi, _drive) do
    Logger.debug("processing: #{inspect(item)}")
    # TODO: actually build a Multi.insert for this item
    multi
  end

  defp update_drive(drive, delta_link) do
    drive
    |> Drive.update_delta_link_changeset(delta_link)
    |> Repo.update()
  end
end
