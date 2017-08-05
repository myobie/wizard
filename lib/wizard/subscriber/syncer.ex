defmodule Wizard.Subscriber.Syncer do
  alias Wizard.Sharepoint
  alias Wizard.Subscriber

  @api_client Application.get_env(:wizard, :sharepoint_api_client)

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
    @api_client.get(delta_link_url(subscriber), access_token: access_token)
    |> process(state)
    |> fetch()
  end

  defp fetch(%{access_token: access_token, delta_link: nil, next_link: next_link} = state) do
    @api_client.get(next_link, access_token: access_token)
    |> process(state)
    |> fetch()
  end

  defp fetch(%{access_token: access_token, delta_link: delta_link, next_link: nil} = state) do
    @api_client.get(delta_link, access_token: access_token)
    |> process(state)
    |> fetch()
  end

  defp process({:ok, %{"@odata.deltaLink" => delta_link, "value" => items}}, state) do
    with {:ok, _} <- process_items(items, state.subscriber),
         {:ok, _} <- Sharepoint.update_drive(state.subscriber.subscription.drive, delta_link: delta_link) do
      %{state | delta_link: delta_link, next_link: nil, done: true} # NOTE: done
    else
      {:error, error} ->
        %{state | error: {:process_error, error}, done: true} # NOTE: done
    end
  end

  defp process({:ok, %{"@odata.nextLink" => next_link, "value" => items}}, state) do
    with {:ok, _} <- process_items(items, state.subscriber) do
      %{state | next_link: next_link, delta_link: nil}
    else
      {:error, error} ->
        %{state | error: {:process_error, error}, done: true} # NOTE: done
    end
  end

  defp process({:error, error}, state) do
    %{state | error: error, done: true} # NOTE: done
  end

  defp process_items(infos, %Subscriber{subscription: %{drive: drive}}) do
    Logger.debug("processing #{length(infos)} items for drive #{drive.id}")
    Sharepoint.insert_or_delete_remote_items(infos, drive: drive)
  end
end
