defmodule Wizard.Subscriber.Syncer do
  alias Wizard.Repo
  alias Ecto.Multi
  alias Wizard.Sharepoint.{Api, Drive, Item}
  alias Wizard.Subscriber

  import Ecto.Changeset, only: [put_assoc: 3, fetch_field: 2]

  use GenServer
  require Logger

  def init(%Subscriber{authorization: %{access_token: access_token}, subscription: %{drive: %{delta_link: delta_link}}} = subscriber) do
    {:ok, %{
      subscriber: subscriber,
      access_token: access_token,
      delta_link: delta_link,
      next_link: nil,
      done: false,
      error: nil
    }}
  end

  def start_link(%Subscriber{} = subscriber) do
    GenServer.start_link(__MODULE__, subscriber, [])
  end

  def start_link_and_sync(%Subscriber{} = subscriber) do
    {:ok, pid} = start_link(subscriber)
    GenServer.cast(pid, :sync)
    {:ok, pid}
  end

  def handle_cast(:sync, state) do
    {:ok, state} = fetch(state) # NOTE: will recurse until done: true
    stop_message(state)
  end

  defp stop_message(%{error: nil} = state), do: {:stop, :normal, state}
  defp stop_message(%{error: error} = state), do: {:stop, {:error, error}, state}

  defp delta_link_url(%Subscriber{subscription: %{drive: %{remote_id: drive_id, site: %{service: %{endpoint_uri: endpoint_uri}}}}}) do
    "#{endpoint_uri}/v2.0/drives/#{drive_id}/root:/:/delta"
  end

  defp fetch(%{done: true} = state), do: {:ok, state} # NOTE: done

  defp fetch(%{subscriber: subscriber, access_token: access_token, delta_link: nil, next_link: nil} = state) do
    Api.get(delta_link_url(subscriber), access_token)
    |> process(state)
    |> fetch()
  end

  defp fetch(%{access_token: access_token, delta_link: nil, next_link: next_link} = state) do
    Api.get(next_link, access_token)
    |> process(state)
    |> fetch()
  end

  defp fetch(%{access_token: access_token, delta_link: delta_link, next_link: nil} = state) do
    Api.get(delta_link, access_token)
    |> process(state)
    |> fetch()
  end

  defp process(%{"@odata.deltaLink" => delta_link, "value" => items}, state) do
    with {:ok, _} <- process_items(items, state.subscriber),
         {:ok, _} <- update_drive(delta_link, state.subscriber) do
      %{state | delta_link: delta_link, next_link: nil, done: true} # NOTE: done
    else
      {:error, error} ->
        %{state | error: {:process_error, error}, done: true} # NOTE: done
    end
  end

  defp process(%{"@odata.nextLink" => next_link, "value" => items}, state) do
    with {:ok, _} <- process_items(items, state.subscriber) do
      %{state | next_link: next_link, delta_link: nil}
    else
      {:error, error} ->
        %{state | error: {:process_error, error}, done: true} # NOTE: done
    end
  end

  defp process(error, state) do
    %{state | error: error, done: true} # NOTE: done
  end

  defp process_items(infos, %Subscriber{subscription: %{drive: drive}}) do
    Logger.debug("processing #{length(infos)} items for #{inspect(drive)}")

    Multi.new
    |> insert_items(infos, drive: drive)
    |> Repo.transaction()
  end

  defp insert_items(multi, [info | infos], [drive: drive]) do
    Logger.debug("processing: #{inspect(info)}")

    changeset = Item.changeset(%Item{}, parse_item(info))
                |> put_assoc(:drive, drive)
                |> put_assoc_parent(info)

    multi
    |> insert_item(changeset)
    |> insert_items(infos, drive: drive)
  end

  defp parse_item(info) do
    %{
      remote_id: info["id"],
      name: info["name"],
      type: item_type(info),
      last_modified_at: get_in(info, ["fileSystemInfo", "lastModifiedDateTime"]),
      size: info["size"],
      url: info["webUrl"],
      full_path: "?"
    }
  end

  defp item_type(%{"folder" => _}), do: "folder"
  defp item_type(_), do: "file"

  defp put_assoc_parent(changeset, %{"parentReference" => %{"driveId" => drive_remote_id, "id" => parent_remote_id}}) do
    {_, drive} = fetch_field(changeset, :drive)

    if drive.remote_id == drive_remote_id do
      case Repo.get_by(Item, remote_id: parent_remote_id) do
        nil -> changeset
        parent_item ->
          changeset |> put_assoc(:parent, parent_item)
      end
    else
      changeset
    end
  end

  defp put_assoc_parent(changeset, _), do: changeset

  defp insert_item(multi, changeset) do
    case fetch_field(changeset, :remote_id) do
      :error ->
        multi
        |> Multi.error({:item, :missing_remote_id}, :missing_item_remote_id)
      {_, remote_id} ->
        multi
        |> Multi.insert({:item, remote_id}, changeset)
    end
  end

  defp update_drive(delta_link, subscriber) do
    subscriber.subscription.drive
    |> Drive.update_delta_link_changeset(delta_link)
    |> Repo.update()
  end
end
