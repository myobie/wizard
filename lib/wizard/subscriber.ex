defmodule Wizard.Subscriber do
  alias Wizard.Repo
  alias Wizard.Sharepoint.Authorization
  alias Wizard.Subscriber.{Server, Subscription}

  import Ecto.Changeset, only: [put_assoc: 3]

  defstruct subscription: nil, pid: nil, authorization: nil

  defmodule AuthorizationNotFoundError do
    defexception [:message]
  end

  def subscribe(user, drive) do
    with {:ok, subscription} <- insert_subscription(drive: drive, user: user),
         {:ok, subscriber} <- start_link(subscription),
         :ok <- sync(subscriber),
      do: subscriber
  end

  def insert_subscription([drive: drive, user: user]) do
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

  def start_link(%Subscription{} = subscription) do
    %__MODULE__{subscription: subscription}
    |> start_link()
  end

  def start_link(%__MODULE__{} = subscriber) do
    with subscriber = preload_and_authorization(subscriber),
         {:ok, pid} <- Server.start_link(subscriber) do
      {:ok, %{subscriber | pid: pid}}
    end
  end

  def sync(%__MODULE__{} = subscriber) do
    GenServer.cast(subscriber.pid, :sync)
  end

  def preload_and_authorization(%__MODULE__{} = subscriber) do
    subscriber
    |> preload()
    |> authorization()
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
