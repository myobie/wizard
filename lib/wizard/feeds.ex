defmodule Wizard.Feeds do
  require Logger

  import Ecto.Query, warn: false
  alias Wizard.{Repo, User}

  alias Wizard.Feeds.{Event, Feed}

  @spec insert_event([type: String.t, actor: User.t, subject: map, payload: map, feed: Feed.t]) :: {:ok, Event.t} | {:error, Ecto.Changeset.t}
  @spec insert_event([type: String.t, actor: User.t, subject: map, payload: map, grouping: String.t, feed: Feed.t]) :: {:ok, Event.t} | {:error, Ecto.Changeset.t}

  def insert_event([type: type, actor: actor, subject: subject, payload: payload, feed: feed]),
    do: insert_event([type: type, actor: actor, subject: subject, payload: payload, grouping: "default", feed: feed])

  def insert_event([type: type, actor: actor, subject: subject, payload: payload, grouping: grouping, feed: feed]) do
    actor_ids = [actor.id]

    attrs = %{
      type: type,
      actor_ids: actor_ids,
      subject_id: subject.id,
      subject_type: subject.type,
      payload: payload,
      grouping: grouping
    }

    query = from e in Event,
              update: [set: [
                updated_at: fragment("EXCLUDED.inserted_at"),
                actor_ids: fragment("EXCLUDED.actor_ids::int[] | ?::int[]", e.actor_ids)
              ]]

    conflict_target = [:feed_id, :type, :subject_id, :subject_type, :grouping]
    on_conflict_options = [on_conflict: query, conflict_target: conflict_target]

    Event.changeset(attrs, feed: feed)
    |> Repo.insert(on_conflict_options)
  end
end
