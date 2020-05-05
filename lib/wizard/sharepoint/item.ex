defmodule Wizard.Sharepoint.Item do
  use Wizard.Schema
  alias Wizard.Sharepoint.{Drive, Item}

  @type t :: %__MODULE__{}

  schema "sharepoint_items" do
    belongs_to :parent, Item
    belongs_to :drive, Drive

    field :remote_id, :string
    field :name, :string
    field :type, :string
    field :last_modified_at, :utc_datetime
    field :size, :integer
    field :url, :string

    deleted_at()
    timestamps()
  end

  @spec changeset(map, [drive: Drive.t, parent: t] | [drive: Drive.t]) :: Ecto.Changeset.t
  @spec changeset(t, map, [drive: Drive.t, parent: t] | [drive: Drive.t]) :: Ecto.Changeset.t

  def changeset(item \\ %Item{}, attrs, list)

  def changeset(%Item{} = item, attrs, [drive: drive]) do
    # TODO: type is an enum

    item
    |> cast(attrs, [:remote_id, :name, :type, :last_modified_at, :size, :url])
    |> validate_required([:remote_id, :name, :type, :last_modified_at, :size, :url])
    |> validate_length([:remote_id, :name], max: 255)
    |> validate_length(:url, max: 3072)
    |> changeset_constraints()
    |> put_assoc(:drive, drive)
  end

  def changeset(%Item{} = item, attrs, [drive: drive, parent: parent]) do
    changeset(item, attrs, drive: drive)
    |> put_assoc(:parent, parent)
  end

  def delete_changeset(%Item{} = item) do
    item
    |> change(deleted_at: DateTime.utc_now())
    |> changeset_constraints()
  end

  defp changeset_constraints(changeset) do
    changeset
    |> foreign_key_constraint(:parent_id)
    |> foreign_key_constraint(:drive_id)
    |> unique_constraint(:remote_id, name: :sharepoint_items_remote_id_and_drive_id_index)
  end

  @spec parse_remote(map) :: map
  def parse_remote(info) do
    %{
      remote_id: info["id"],
      name: info["name"],
      type: remote_item_type(info),
      last_modified_at: get_in(info, ["fileSystemInfo", "lastModifiedDateTime"]),
      size: info["size"],
      url: info["webUrl"],
      parent_remote_id: assoc_remote_parent_remote_id(info),
      user: extract_user_info(info)
    }
  end

  @spec remote_item_type(map) :: String.t
  defp remote_item_type(%{"root" => _}), do: "root"
  defp remote_item_type(%{"folder" => _}), do: "folder"
  defp remote_item_type(_), do: "file"

  @spec assoc_remote_parent_remote_id(map) :: nil | String.t
  def assoc_remote_parent_remote_id(%{"parentReference" => %{"id" => parent_remote_id}}), do: to_string(parent_remote_id)
  def assoc_remote_parent_remote_id(_), do: nil

  @spec extract_user_info(map) :: nil | map
  defp extract_user_info(%{"lastModifiedBy" => %{"user" => info}}),
    do: extract_user_info_from_identity(info)

  defp extract_user_info(%{"createdBy" => %{"user" => info}}),
    do: extract_user_info_from_identity(info)

  defp extract_user_info(_), do: nil

  @spec extract_user_info_from_identity(map) :: map
  defp extract_user_info_from_identity(info) do
    %{
      name: info["displayName"],
      email: info["email"]
    }
  end
end
