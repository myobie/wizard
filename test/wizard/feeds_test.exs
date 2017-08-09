defmodule Wizard.FeedsTest do
  use Wizard.DataCase
  import Wizard.Factory
  require Logger

  alias Wizard.Feeds
  alias Feeds.Event

  setup do
    {:ok, %{feed: insert(:feed),
            user: insert(:user)}}
  end

  test "can insert feed events", %{feed: feed, user: actor} do
    other_actor = insert(:user)

    {:ok, _} = Feeds.insert_event type: "file.update",
                                  actor: actor,
                                  subject: %{id: 1, type: "file"},
                                  payload: %{summary: "updated a new file"},
                                  feed: feed

    {:ok, _} = Feeds.insert_event type: "file.update",
                                  actor: other_actor,
                                  subject: %{id: 1, type: "file"},
                                  payload: %{summary: "updated a new file"},
                                  feed: feed

    {:ok, _} = Feeds.insert_event type: "file.update",
                                  actor: other_actor,
                                  subject: %{id: 1, type: "file"},
                                  payload: %{summary: "updated a new file"},
                                  feed: feed

    event = Repo.one(Event)

    assert event.actor_ids == [actor.id, other_actor.id]
  end

  test "groups events by their grouping", %{user: user1, feed: feed} do
    user2 = insert(:user)
    user3 = insert(:user)

    {:ok, _} = Feeds.insert_event type: "file.update",
                                  actor: user1,
                                  subject: %{id: 1, type: "file"},
                                  payload: %{summary: "updated a new file"},
                                  grouping: "a",
                                  feed: feed

    {:ok, _} = Feeds.insert_event type: "file.update",
                                  actor: user2,
                                  subject: %{id: 1, type: "file"},
                                  payload: %{summary: "updated a new file"},
                                  grouping: "a",
                                  feed: feed

    # repeat
    {:ok, _} = Feeds.insert_event type: "file.update",
                                  actor: user2,
                                  subject: %{id: 1, type: "file"},
                                  payload: %{summary: "updated a new file"},
                                  grouping: "a",
                                  feed: feed

    {:ok, _} = Feeds.insert_event type: "file.update",
                                  actor: user2,
                                  subject: %{id: 1, type: "file"},
                                  payload: %{summary: "updated a new file"},
                                  grouping: "b",
                                  feed: feed

    {:ok, _} = Feeds.insert_event type: "file.update",
                                  actor: user3,
                                  subject: %{id: 1, type: "file"},
                                  payload: %{summary: "updated a new file"},
                                  grouping: "b",
                                  feed: feed

    # repeat
    {:ok, _} = Feeds.insert_event type: "file.update",
                                  actor: user2,
                                  subject: %{id: 1, type: "file"},
                                  payload: %{summary: "updated a new file"},
                                  grouping: "b",
                                  feed: feed

    assert Repo.aggregate(Event, :count, :id) == 2

    # prove that there are only two events and they both have exactly the correct actor ids

    query = Ecto.Query.from e in Event, select: e.actor_ids, order_by: e.id

    assert Repo.all(query) == [[user1.id, user2.id], [user2.id, user3.id]]
  end
end
