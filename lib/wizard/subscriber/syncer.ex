defmodule Wizard.Subscriber.Syncer do
  alias Wizard.Sharepoint
  alias Wizard.Subscriber

  use GenServer
  require Logger

  def init(%Subscriber{authorization: %{access_token: access_token}, subscription: %{drive: drive}} = subscriber) do
    {:ok, %{
      subscriber: subscriber,
      drive: drive,
      access_token: access_token,
      done: false,
      error: nil
    }}
  end

  def start(%Subscriber{} = subscriber) do
    GenServer.start(__MODULE__, subscriber, [])
  end

  def start_and_sync(%Subscriber{} = subscriber) do
    {:ok, pid} = start(subscriber)
    GenServer.cast(pid, :sync)
    {:ok, pid}
  end

  def handle_cast(:sync, %{drive: drive, access_token: access_token} = state) do
    Sharepoint.sync(drive, access_token: access_token)
    |> stop_message(state)
  end

  defp stop_message({:ok, _}, state), do: {:stop, :normal, state}
  defp stop_message({:error, error}, state), do: {:stop, {:error, error}, state}
end
