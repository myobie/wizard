defmodule Wizard.Sharepoint.Drive do
  use Ecto.Schema
  @timestamps_opts [type: :utc_datetime, usec: true]
  import Ecto.Changeset
  alias Wizard.Sharepoint.{Authorization, Drive}

  schema "sharepoint_drives" do
    belongs_to :authorization, Authorization

    field :remote_id, :string
    field :name, :string
    field :type, :string
    field :url, :string
    field :delta_link, :string

    timestamps()
  end

  @doc false
  def changeset(%Drive{} = drive, attrs) do
    drive
    |> cast(attrs, [:remote_id, :name, :url, :type, :delta_link])
    |> validate_required([:remote_id, :name, :url, :type])
    |> foreign_key_constraint(:authorization_id)
    |> unique_constraint(:authorization_id, name: :sharepoint_drives_authorization_id_and_remote_id_index)
  end

  @doc false
  def update_delta_link_changeset(%Drive{} = drive, delta_link) do
    drive
    |> cast(%{delta_link: delta_link}, [:delta_link])
    |> validate_required([:delta_link])
  end
end
