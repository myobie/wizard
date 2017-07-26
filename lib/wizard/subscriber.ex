defmodule Wizard.Subscriber do
  alias Wizard.Repo
  alias Wizard.Sharepoint.{Authorization}
  alias Wizard.Subscriber.Server

  def subscribe() do
  end

  def unsubscribe(_subscription) do
  end

  def start_link(subscription) do
    subscription = preload(subscription)
    authorization = authorization(subscription)
    Server.start_link({subscription, authorization})
  end

  def sync(pid) do
    GenServer.cast(pid, :sync)
  end

  def preload(subscription) do
    subscription
    |> Repo.preload(drive: [site: :service])
    |> Repo.preload(:user)
  end

  def authorization(subscription) do
    case Repo.get_by(Authorization, user_id: subscription.user.id, service_id: subscription.drive.site.service.id) do
      nil -> {:error, :not_found}
      authorization -> {:ok, authorization}
    end
  end
end
