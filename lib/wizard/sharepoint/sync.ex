defmodule Wizard.Sharepoint.Sync do
  require Logger

  alias Wizard.Sharepoint
  alias Wizard.Sharepoint.Drive
  alias Wizard.Sharepoint.Api.Files

  @spec run(Drive.t, [access_token: String.t]) :: {:ok, Drive.t} | {:error, any}
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
    Files.delta(drive, access_token: access_token)
    |> process(state)
    |> fetch()
  end

  defp fetch(%{access_token: access_token,
               delta_link: nil,
               next_link: next_link} = state)
  do
    Files.next(next_link, access_token: access_token)
    |> process(state)
    |> fetch()
  end

  defp fetch(%{access_token: access_token,
               delta_link: delta_link,
               next_link: nil} = state)
  do
    Files.next(delta_link, access_token: access_token)
    |> process(state)
    |> fetch()
  end

  defp process({:error, error}, state) do
    %{state | error: error, done: true} # NOTE: done
  end

  defp process({:ok, resp}, state),
    do: process(resp, state)

  defp process(%{"@odata.deltaLink" => delta_link, "value" => items},
               %{drive: drive} = state)
  do
    with :ok <- process_items(items, drive),
         {:ok, drive} <- Sharepoint.update_drive(drive, delta_link: delta_link) do
      %{state | drive: drive, delta_link: nil, next_link: nil, done: true} # NOTE: done
    else
      {:error, error} ->
        %{state | error: {:process_error, error}, done: true} # NOTE: done
    end
  end

  defp process(%{"@odata.nextLink" => next_link, "value" => items},
               %{drive: drive} = state)
  do
    with :ok <- process_items(items, drive) do
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
end
