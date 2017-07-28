defmodule Wizard.Sharepoint.Item do
  use Wizard.Schema
  alias Wizard.Sharepoint.{Drive, Item}

  schema "sharepoint_items" do
    belongs_to :parent, Item
    belongs_to :drive, Drive

    field :remote_id, :string
    field :name, :string
    field :type, :string
    field :last_modified_at, :utc_datetime
    field :size, :integer
    field :url, :string
    field :full_path, :string

    deleted_at()
    timestamps()
  end

  @doc false
  def changeset(%Item{} = item, attrs) do
    item
    |> cast(attrs, [:remote_id, :name, :type, :last_modified_at, :size, :url, :full_path])
    |> validate_required([:remote_id, :name, :type, :last_modified_at, :size, :url, :full_path])
    |> foreign_key_constraint(:drive_id)
    |> foreign_key_constraint(:parent_id)
    |> unique_constraint(:remote_id)
  end

  def delete_changeset(%Item{} = item) do
    item
    |> change(deleted_at: DateTime.utc_now())
    |> foreign_key_constraint(:drive_id)
    |> foreign_key_constraint(:parent_id)
    |> unique_constraint(:remote_id)
  end

  def parse_remote(info) do
    %{
      remote_id: info["id"],
      name: info["name"],
      type: remote_item_type(info),
      last_modified_at: get_in(info, ["fileSystemInfo", "lastModifiedDateTime"]),
      size: info["size"],
      url: info["webUrl"],
      full_path: "?",
      parent_remote_id: assoc_remote_parent_remote_id(info)
    }
  end

  defp remote_item_type(%{"folder" => _}), do: "folder"
  defp remote_item_type(_), do: "file"

  defp assoc_remote_parent_remote_id(%{"parentReference" => %{"id" => parent_remote_id}}), do: parent_remote_id
  defp assoc_remote_parent_remote_id(_), do: nil
end
