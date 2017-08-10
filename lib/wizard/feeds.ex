defmodule Wizard.Feeds do
  require Logger

  import Ecto.Query, warn: false

  alias Wizard.{Repo, User}
  alias Wizard.Sharepoint.{Drive}
  alias Wizard.Feeds.{Event, Feed}

  @type event_info :: [type: String.t, actor: User.t, subject: map, payload: map, feed: Feed.t] |
                      [type: String.t, actor: User.t, subject: map, payload: map, grouping: String.t, feed: Feed.t]

  @type db_result :: {:ok, Event.t} | {:error, Ecto.Changeset.t}

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

  @spec upsert_feed([drive: Drive.t]) :: {:ok, Drive.t} | {:error, Ecto.Changeset.t}
  def upsert_feed([drive: drive]) do
    Feed.changeset(drive: drive)
    |> Repo.insert([on_conflict: :nothing,
                    conflict_target: :drive_id,
                    returning: true])
  end
end
