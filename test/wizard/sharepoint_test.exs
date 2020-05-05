defmodule Wizard.SharepointTest do
  use Wizard.DataCase
  import Wizard.Factory
  require Logger

  alias Wizard.{Sharepoint, User}
  alias Sharepoint.Item
  alias Wizard.Feeds.Event

  @sync_response_1 Poison.decode!(File.read!("test/fixtures/sharepoint/sync_response_1.json"))

  setup do
    {:ok,
     %{infos: @sync_response_1["value"],
       drive: insert(:sharepoint_drive),
       feed: insert(:feed)}}
  end

  test "can process items from initial sync", %{infos: infos, drive: drive, feed: feed} do
    assert Repo.aggregate(Item, :count, :id) == 0

    :ok = Sharepoint.upsert_or_delete_remote_items(infos, drive: drive, feed: feed)

    assert Repo.aggregate(Item, :count, :id) == 3
    assert Repo.aggregate(User, :count, :id) == 2
    assert Repo.aggregate(Event, :count, :id) == 1
  end

  test "can discover parents", %{infos: infos, drive: drive} do
    insert(:sharepoint_item, remote_id: "item-id-1", drive: drive)
    insert(:sharepoint_item, remote_id: "item-id-2", drive: drive)

    parents = Sharepoint.discover_parents(infos, drive: drive)

    assert match?(%{"item-id-1" => %Item{},
                    "item-id-2" => %Item{}},
                  parents)
  end

  test "can handle duplicate items", %{infos: infos, drive: drive, feed: feed} do
    :ok = Sharepoint.upsert_or_delete_remote_items(infos, drive: drive, feed: feed)
    :ok = Sharepoint.upsert_or_delete_remote_items(infos, drive: drive, feed: feed)

    assert Repo.aggregate(Item, :count, :id) == 3
    assert Repo.aggregate(User, :count, :id) == 2
    assert Repo.aggregate(Event, :count, :id) == 1
  end
end
