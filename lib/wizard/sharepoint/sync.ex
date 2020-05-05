defmodule Wizard.Sharepoint.Sync do
  require Logger

  alias Wizard.Sharepoint
  alias Wizard.Sharepoint.{Api, Drive}

  @spec run(Drive.t, Api.access) :: {:ok, Drive.t} | {:error, any}
  def run(%Drive{} = drive, [access_token: access_token]) do
    %{
      drive: drive,
      delta_link: drive.delta_link,
      next_link: nil,
      done: false,
      access_token: access_token,
      error: nil
    }
    |> fetch()
  end

  defp fetch(%{done: true, error: nil, drive: drive}), do: {:ok, drive}
  defp fetch(%{done: true, error: error}), do: {:error, error}

  defp fetch(%{drive: drive,
               access_token: access_token,
               delta_link: nil,
               next_link: nil} = state)
  do
    Api.Files.delta(drive, access_token: access_token)
    |> process(state)
    |> fetch()
  end

  defp fetch(%{access_token: access_token,
               delta_link: nil,
               next_link: next_link} = state)
  do
    Api.Files.next(next_link, access_token: access_token)
    |> process(state)
    |> fetch()
  end

  defp fetch(%{access_token: access_token,
               delta_link: delta_link,
               next_link: nil} = state)
  do
    Api.Files.next(delta_link, access_token: access_token)
    |> process(state)
    |> fetch()
  end

  defp process({:error, :reset_delta_url}, %{drive: drive} = state) do
    delta_link = Api.Files.reset_delta_url(drive)
    %{state | delta_link: delta_link}
  end

  defp process({:error, error}, state) do
    %{state | error: error, done: true} # NOTE: done
  end

  defp process({:ok, resp}, state),
    do: process(resp, state)

  defp process(%{"@odata.deltaLink" => delta_link, "value" => items},
               %{drive: drive, access_token: access_token} = state)
  do
    with items = filter_items(items),
      {:ok, items} <- Api.Files.get_items(items, drive, access_token: access_token),
      :ok <- process_items(items, drive),
      {:ok, drive} <- Sharepoint.update_drive(drive, delta_link: delta_link)
    do
      %{state | drive: drive, delta_link: nil, next_link: nil, done: true} # NOTE: done
    else
      {:error, error} ->
        %{state | error: {:process_error, error}, done: true} # NOTE: done
    end
  end

  defp process(%{"@odata.nextLink" => next_link, "value" => items},
               %{drive: drive, access_token: access_token} = state)
  do
    with items = filter_items(items),
      {:ok, items} <- Api.Files.get_items(items, drive, access_token: access_token),
      :ok <- process_items(items, drive)
    do
      %{state | next_link: next_link, delta_link: nil}
    else
      {:error, error} ->
        %{state | error: {:process_error, error}, done: true} # NOTE: done
    end
  end

  defp process_items(infos, %Drive{} = drive) do
    Logger.debug("processing #{length(infos)} items for drive #{drive.id}")
    Sharepoint.upsert_or_delete_remote_items(infos, drive: drive)
  end

  @app_regex ~r{\.app/Contents/}

  defp filter_items(infos),
    do: Enum.filter(infos, &keep_item/1)

  defp keep_item(info),
    do: not Regex.match?(@app_regex, Map.get(info, "webUrl", ""))
end
