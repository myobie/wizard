defmodule Wizard.Subscriber do
  require Logger

  alias Wizard.{Feeds, Repo, Sharepoint, User}
  alias Wizard.Sharepoint.{Authorization, Drive}
  alias Wizard.Subscriber.{Server, Subscription}

  defstruct subscription: nil, pid: nil, authorization: nil, feed: nil

  defmodule AuthorizationNotFoundError do
    defexception [:message]
  end

  defmodule FeedNotCreatedError do
    defexception [:message]
  end

  @type t :: %__MODULE__{}

  @type on_start :: {:ok, t} |
                 :ignore |
                 {:error, {:already_started, pid} | term}

  @spec start_all_subscriptions() :: {:ok, list(t)} |
                                     {:error, on_start, list(t)}
  def start_all_subscriptions do
    start_subscriptions([], Repo.all(Subscription))
  end

  @spec start_subscriptions(list(t), list(Subscription.t)) :: {:ok, list(t)} |
                                                              {:error, on_start, list(t)}
  defp start_subscriptions(result, []), do: {:ok, result}
  defp start_subscriptions(result, [subscription | subscriptions]) do
    case start_link(subscription) do
      {:ok, sub} -> start_subscriptions([sub | result], subscriptions)
      error -> {:error, error, result}
    end
  end

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

  @spec start_link(Subscription.t | t) :: on_start
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

  @spec stop(t) :: :ok
  def stop(%__MODULE__{} = subscriber) do
    GenServer.stop(subscriber.pid)
  end

  @spec sync(t) :: :ok
  def sync(%__MODULE__{} = subscriber) do
    GenServer.cast(subscriber.pid, :sync)
  end

  @spec preload_and_authorization(t) :: t
  def preload_and_authorization(%__MODULE__{} = subscriber) do
    subscriber
    |> preload()
    |> setup_feed()
    |> authorization()
  end

  def setup_feed(%__MODULE__{subscription: %{drive: drive}} = subscriber) do
    case Feeds.upsert_feed(drive: drive) do
      {:ok, feed} ->
        %{subscriber | feed: feed}
      _ ->
        raise FeedNotCreatedError, message: "drive '#{drive.id}' doesn't have an associated feed"
    end
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

  def reauthorize(%__MODULE__{authorization: authorization} = subscriber) do
    result = Repo.preload(authorization, :service)
             |> Sharepoint.reauthorize()

    case result do
      {:ok, authorization} ->
        %{subscriber | authorization: authorization}
      {:error, error} ->
        Logger.error("Reauthorization failed #{inspect({:error, error, subscriber})}")
        subscriber
    end
  end
end
