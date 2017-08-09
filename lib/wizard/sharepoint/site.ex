defmodule Wizard.Sharepoint.Site do
  use Wizard.Schema
  alias Wizard.Sharepoint.{Service, Site}

  @type t :: %__MODULE__{}

  schema "sharepoint_sites" do
    belongs_to :service, Service

    field :remote_id, :string
    field :url, :string
    field :hostname, :string
    field :title, :string
    field :description, :string

    timestamps()
  end

  @spec changeset(map, [service: Service.t]) :: Ecto.Changeset.t
  @spec changeset(t, map, [service: Service.t]) :: Ecto.Changeset.t
  def changeset(%Site{} = site \\ %Site{}, attrs, [service: service]) do
    site
    |> cast(attrs, [:remote_id, :hostname, :title, :url, :description])
    |> validate_required([:remote_id, :hostname, :title, :url])
    |> validate_length([:remote_id, :hostname], max: 255)
    |> validate_length([:url, :title], max: 1024)
    |> truncate_length(:description, 2048)
    |> foreign_key_constraint(:service_id)
    |> unique_constraint(:remote_id)
    |> put_assoc(:service, service)
  end

  def on_conflict_options(%Changeset{} = changeset) do
    changeset
    |> fetch_fields([:hostname, :title, :url, :description])
  end
end
