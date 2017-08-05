defmodule Wizard.SharepointTest do
  use Wizard.DataCase
  import Wizard.Factory
  require Logger

  alias Wizard.Sharepoint
  alias Sharepoint.Item

  @sync_response_1 Poison.decode!(File.read!("test/fixtures/sharepoint/sync_response_1.json"))

  setup do
    infos = @sync_response_1["value"]

    {:ok, %{infos: infos}}
  end

  test "can process items from initial sync", %{infos: infos} do
    assert Repo.aggregate(Item, :count, :id) == 0

    drive = insert(:sharepoint_drive)

    Sharepoint.insert_or_delete_remote_items(infos, drive: drive)

    assert Repo.aggregate(Item, :count, :id) == 3
  end

  test "can discover parents", %{infos: infos} do
    drive = insert(:sharepoint_drive)
    insert(:sharepoint_item, remote_id: "item-id-1", drive: drive)
    insert(:sharepoint_item, remote_id: "item-id-2", drive: drive)

    parents = Sharepoint.discover_parents(infos, drive: drive)

    assert match?(%{"item-id-1" => %Item{},
                    "item-id-2" => %Item{}},
                  parents)
  end

  test "can handle duplicate items", %{infos: infos} do
    drive = insert(:sharepoint_drive)

    Sharepoint.insert_or_delete_remote_items(infos, drive: drive)
    Sharepoint.insert_or_delete_remote_items(infos, drive: drive)

    assert Repo.aggregate(Item, :count, :id) == 3
  end
end
