defmodule Wizard.Sharepoint.Drive do
  use Wizard.Schema
  alias Wizard.Sharepoint.{Drive, Site}

  schema "sharepoint_drives" do
    belongs_to :site, Site

    field :remote_id, :string
    field :name, :string
    field :type, :string
    field :url, :string
    field :delta_link, :string

    timestamps()
  end

  @doc false
  def changeset(%Drive{} = drive, attrs) do
    # TODO: type is an enum

    drive
    |> cast(attrs, [:remote_id, :name, :url, :type, :delta_link])
    |> validate_required([:remote_id, :name, :url, :type])
    |> validate_length([:remote_id, :name], max: 255)
    |> validate_length(:url, max: 1024)
    |> validate_length(:delta_link, max: 2048)
    |> foreign_key_constraint(:site_id)
    |> unique_constraint(:remote_id)
  end

  @doc false
  def update_delta_link_changeset(%Drive{} = drive, delta_link) do
    drive
    |> cast(%{delta_link: delta_link}, [:delta_link])
    |> validate_required([:delta_link])
  end
end
