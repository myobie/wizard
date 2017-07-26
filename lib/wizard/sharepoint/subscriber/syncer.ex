defmodule Wizard.Sharepoint.Subscriber.Syncer do
  alias Wizard.Repo
  alias Ecto.Multi
  alias Wizard.Sharepoint.{Api, Authorization, Drive, Service, Site}

  use GenServer
  require Logger

  def init({%Drive{delta_link: delta_link} = drive, %Authorization{} = authorization}) do
    {:ok, %{
      drive: drive,
      authorization: authorization,
      delta_link: delta_link,
      next_link: nil,
      done: false,
      error: nil
    }}
  end

  def start_link({drive, authorization}) do
    drive = drive |> Repo.preload(site: :service) # NOTE: make sure we have the site so we have the URL for API calls
    GenServer.start_link(__MODULE__, {drive, authorization}, [])
  end

  def start_link_and_sync(args) do
    {:ok, pid} = start_link(args)
    GenServer.cast(pid, :sync)
    {:ok, pid}
  end

  def handle_cast(:sync, state) do
    {:ok, state} = fetch(state) # NOTE: will recurse until done: true
    stop_message(state)
  end

  defp stop_message(%{error: nil} = state), do: {:stop, :normal, state}
  defp stop_message(%{error: error} = state), do: {:stop, {:error, error}, state}

  defp access_token(%Authorization{access_token: access_token}), do: access_token

  defp delta_link_url(%Drive{remote_id: drive_id, site: %Site{service: %Service{endpoint_uri: endpoint_uri}}}) do
    "#{endpoint_uri}/v2.0/drives/#{drive_id}/root:/:/delta"
  end

  defp fetch(%{done: true} = state), do: state # NOTE: done

  defp fetch(%{drive: drive, authorization: auth, delta_link: nil, next_link: nil} = state) do
    Api.get(delta_link_url(drive), access_token(auth))
    |> process(state)
    |> fetch()
  end

  defp fetch(%{authorization: auth, delta_link: nil, next_link: next_link} = state) do
    Api.get(next_link, access_token(auth))
    |> process(state)
    |> fetch()
  end

  defp fetch(%{authorization: auth, delta_link: delta_link, next_link: nil} = state) do
    Api.get(delta_link, access_token(auth))
    |> process(state)
    |> fetch()
  end

  defp process(%{"@odata.deltaLink" => delta_link, "value" => items}, %{drive: drive} = state) do
    with {:ok, _} <- process_items(items, drive),
         {:ok, _} <- update_drive(drive, delta_link) do
      %{state | delta_link: delta_link, next_link: nil, done: true} # NOTE: done
    else
      {:error, error} ->
        %{state | error: {:process_error, error}, done: true} # NOTE: done
    end
  end

  defp process(%{"@odata.nextLink" => next_link, "value" => items}, %{drive: drive} = state) do
    with {:ok, _} <- process_items(items, drive) do
      %{state | next_link: next_link, delta_link: nil}
    else
      {:error, error} ->
        %{state | error: {:process_error, error}, done: true} # NOTE: done
    end
  end

  defp process_items(items, %Drive{} = drive) do
    Logger.debug("processing #{length(items)} items")
    Enum.reduce(items, Multi.new, fn item, multi ->
      process_item(item, multi, drive)
    end)
    |> Repo.transaction()
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
