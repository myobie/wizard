defmodule Wizard.Subscriber do
  alias Wizard.{Repo, User}
  alias Wizard.Sharepoint.{Authorization, Drive}
  alias Wizard.Subscriber.{Server, Subscription}

  defstruct subscription: nil, pid: nil, authorization: nil

  defmodule AuthorizationNotFoundError do
    defexception [:message]
  end

  @type t :: %__MODULE__{}

  @spec subscribe(User.t, Drive.t) :: t
  def subscribe(user, drive) do
    with {:ok, subscription} <- insert_subscription(drive: drive, user: user),
         {:ok, subscriber} <- start_link(subscription),
         :ok <- sync(subscriber),
      do: subscriber
  end

  @spec insert_subscription([drive: Drive.t, user: User.t]) :: {:ok, Subscription.t} | {:error, Ecto.Changeset.t}
  def insert_subscription([drive: drive, user: user]) do
    Subscription.changeset(drive: drive, user: user)
    |> Repo.insert()
  end

  @spec unsubscribe(t) :: {:ok, t}
  def unsubscribe(%__MODULE__{} = subscriber) do
    with {:ok, _} <- Repo.delete(subscriber.subscription),
         :ok <- GenServer.stop(subscriber.pid),
         do: {:ok, subscriber}
  end

  @spec start_link(Subscription.t | t) :: {:ok, t}
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

  @spec sync(t) :: :ok
  def sync(%__MODULE__{} = subscriber) do
    GenServer.cast(subscriber.pid, :sync)
  end

  @spec preload_and_authorization(t) :: t
  def preload_and_authorization(%__MODULE__{} = subscriber) do
    subscriber
    |> preload()
    |> authorization()
  end

  @spec preload(t) :: t
  def preload(%__MODULE__{subscription: subscription} = subscriber) do
    subscription = subscription
                   |> Repo.preload(drive: [site: :service])
                   |> Repo.preload(:user)

    %{subscriber | subscription: subscription}
  end

  @spec authorization(t) :: t
  def authorization(%__MODULE__{subscription: %{user: %{id: user_id}, drive: %{site: %{service: %{id: service_id}}}}} = subscriber) do
    case Repo.get_by(Authorization, user_id: user_id, service_id: service_id) do
      nil ->
        raise AuthorizationNotFoundError, message: "subscription '#{subscriber.subscription.id}' does not have an associated sharepoint_authorizations record"
      authorization ->
        %{subscriber | authorization: authorization}
    end
  end

  def reload_subscription(%__MODULE__{subscription: subscription} = subscriber) do
    subscription = Repo.get(Subscription, subscription.id)

    %{subscriber | subscription: subscription}
    |> preload()
  end
end
