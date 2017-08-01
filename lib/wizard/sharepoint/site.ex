defmodule Wizard.Sharepoint.Site do
  use Wizard.Schema
  alias Wizard.Sharepoint.{Service, Site}

  schema "sharepoint_sites" do
    belongs_to :service, Service

    field :remote_id, :string
    field :url, :string
    field :hostname, :string
    field :title, :string
    field :description, :string

    timestamps()
  end

  def changeset(%Site{} = site, attrs) do
    site
    |> cast(attrs, [:remote_id, :hostname, :title, :url, :description])
    |> validate_required([:remote_id, :hostname, :title, :url])
    |> validate_length([:remote_id, :hostname], max: 255)
    |> validate_length([:url, :title], max: 1024)
    |> truncate_length(:description, 2048)
    |> foreign_key_constraint(:service_id)
    |> unique_constraint(:remote_id)
  end

  def on_conflict_options(%Changeset{} = changeset) do
    changeset
    |> fetch_fields([:hostname, :title, :url, :description])
  end
end
