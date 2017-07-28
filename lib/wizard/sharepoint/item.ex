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
end
