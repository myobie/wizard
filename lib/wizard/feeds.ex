defmodule Wizard.Feeds do
  require Logger

  import Ecto.Query, warn: false

  alias Wizard.{Repo, User}
  alias Wizard.Sharepoint.{Drive, Item}
  alias Wizard.Feeds.{Event, Feed}
  alias Wizard.Subscriber.Subscription

  @type event_info :: [type: String.t, actor: User.t, subject: map, payload: map, feed: Feed.t] |
                      [type: String.t, actor: User.t, subject: map, payload: map, grouping: String.t, feed: Feed.t]

  @type db_result :: {:ok, Event.t} | {:error, Ecto.Changeset.t}

  @type indexed_users :: %{optional(String.t) => User.t}

  @type id :: non_neg_integer
  @type ids :: list(id)

  def all_events do
    events = from(e in Event, order_by: [desc: e.updated_at], limit: 10)
             |> Repo.all()

    user_ids = events
               |> Enum.flat_map(&(&1.actor_ids))
               |> Enum.uniq()

    users = from(u in User, where: u.id in ^user_ids)
            |> Repo.all()

    indexed_users = for u <- users, into: %{}, do: {u.id, u}

    events = for e <- events, do: preload_event_actors(e, indexed_users)

    events
    |> Repo.preload(:previews)
  end

  @spec preload_event_subscription(Event.t) :: Event.t
  def preload_event_subscription(%Event{} = event) do
    event = Repo.preload(event, :feed)

    sub = from(s in Subscription,
               where: s.drive_id == ^event.feed.drive_id,
               preload: :user,
               limit: 1)
               |> Repo.one()

    %{event | subscription: sub}
  end

  @spec preload_event_subject(Event.t) :: Event.t
  def preload_event_subject(%Event{subject_type: "sharepoint.item", subject_id: subject_id, subject: nil} = event) do
    subject = Repo.get(Item, subject_id)
    %{event | subject: subject}
  end
  def preload_event_subject(%Event{} = event), do: event

  @spec preload_event_actors(Event.t, indexed_users) :: Event.t
  def preload_event_actors(%Event{actors: nil} = event, %{} = users) do
    actors = find_users(users, event.actor_ids)
    %{event | actors: actors}
  end
  def preload_event_actors(%Event{} = event, _sers), do: event

  @spec find_users(indexed_users, ids) :: list(User.t)
  defp find_users(%{} = users, user_ids),
    do: find_users([], users, user_ids)

  @spec find_users(list(User.t), indexed_users, ids) :: list(User.t)
  defp find_users(result, _users, []), do: result
  defp find_users(result, %{} = users, [user_id | user_ids]) do
    case Map.get(users, user_id) do
      nil -> find_users(result, users, user_ids)
      user -> find_users([user | result], users, user_ids)
    end
  end

  @spec event_changeset(event_info) :: Ecto.Changeset.t
  def event_changeset([type: type, actor: actor, subject: subject, payload: payload, feed: feed]),
    do: event_changeset([type: type, actor: actor, subject: subject, payload: payload, grouping: "default", feed: feed])

  def event_changeset([type: type, actor: actor, subject: subject, payload: payload, grouping: grouping, feed: feed]) do
    actor_ids = [actor.id]

    attrs = %{
      type: type,
      actor_ids: actor_ids,
      subject_id: subject.id,
      subject_type: subject.type,
      payload: payload,
      grouping: grouping
    }

    Event.changeset(attrs, feed: feed)
  end

  @conflict_query from e in Event,
                    update: [set: [
                      updated_at: fragment("EXCLUDED.inserted_at"),
                      actor_ids: fragment("EXCLUDED.actor_ids::int[] | ?::int[]", e.actor_ids)
                    ]]

  @conflict_fields [:feed_id, :type, :subject_id, :subject_type, :grouping]

  @on_conflict_options [on_conflict: @conflict_query,
                        conflict_target: @conflict_fields]

  @spec upsert_event(event_info) :: db_result
  def upsert_event(opts) do
    opts
    |> event_changeset()
    |> Repo.insert(@on_conflict_options)
  end

  @feed_conflict_query from f in Feed,
                         update: [set: [
                           drive_id: fragment("EXCLUDED.drive_id")
                         ]]

  @feed_conflict_options [on_conflict: @feed_conflict_query,
                          conflict_target: :drive_id,
                          returning: true]

  @spec upsert_feed([drive: Drive.t]) :: {:ok, Drive.t} | {:error, Ecto.Changeset.t}
  def upsert_feed([drive: drive]) do
    Feed.changeset(drive: drive)
    |> Repo.insert(@feed_conflict_options)
  end
end
