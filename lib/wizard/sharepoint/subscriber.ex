defmodule Wizard.Sharepoint.Subscriber do
  alias Wizard.Sharepoint.Subscriber.Server

  def start_link(drive) do
    Server.start_link(drive)
  end

  def sync(subscriber) do
    GenServer.cast(subscriber, :sync)
  end
end
