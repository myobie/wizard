defmodule Wizard.Subscriber do
  alias Wizard.Repo
  alias Wizard.Sharepoint.{Authorization}
  alias Wizard.Subscriber.{Server, Subscription}

  import Ecto.Changeset, only: [put_assoc: 3]

  defstruct subscription: nil, pid: nil, authorization: nil

  defmodule AuthorizationNotFoundError do
    defexception [:message]
  end

  def subscribe(user, drive) do
    with {:ok, subscription} <- insert_subscription(drive: drive, user: user) do
      {:ok, pid} = start_link(subscription)
      {:ok, %__MODULE__{subscription: subscription, pid: pid}}
    end
  end

  defp insert_subscription([drive: drive, user: user]) do
    Subscription.changeset()
    |> put_assoc(:drive, drive)
    |> put_assoc(:user, user)
    |> Repo.insert()
  end

  def unsubscribe(%__MODULE__{} = subscriber) do
    with {:ok, _} <- Repo.delete(subscriber.subscription),
         :ok <- GenServer.stop(subscriber.pid),
         do: {:ok, subscriber}
  end

  def start_link(%__MODULE__{} = subscriber) do
    preload(subscriber)
    |> authorization()
    |> Server.start_link()
  end

  def sync(%__MODULE__{} = subscriber) do
    GenServer.cast(subscriber.pid, :sync)
  end

  def preload(%__MODULE__{subscription: subscription} = subscriber) do
    subscription = subscription
                   |> Repo.preload(drive: [site: :service])
                   |> Repo.preload(:user)

    %{subscriber | subscription: subscription}
  end

  def authorization(%__MODULE__{subscription: %{user: %{id: user_id}, drive: %{site: %{service: %{id: service_id}}}}} = subscriber) do
    case Repo.get_by(Authorization, user_id: user_id, service_id: service_id) do
      nil ->
        raise AuthorizationNotFoundError, message: "subscription '#{subscriber.subscription.id}' does not have an associated sharepoint_authorizations record"
      authorization ->
        %{subscriber | authorization: authorization}
    end
  end
end
