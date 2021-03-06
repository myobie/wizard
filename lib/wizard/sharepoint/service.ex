defmodule Wizard.Sharepoint.Service do
  use Wizard.Schema
  alias Wizard.Sharepoint.{Authorization, Service, Site}

  @type t :: %__MODULE__{}

  schema "sharepoint_services" do
    has_many :authorizations, Authorization
    has_many :sites, Site

    field :resource_id, :string
    field :endpoint_uri, :string
    field :title, :string

    timestamps()
  end

  @spec changeset(map) :: Ecto.Changeset.t
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%Service{} = service \\ %Service{}, attrs) do
    service
    |> cast(attrs, [:resource_id, :endpoint_uri, :title])
    |> validate_required([:resource_id, :endpoint_uri, :title])
    |> truncate_length(:title, 1024)
    |> validate_length([:resource_id, :endpoint_uri], max: 255)
    |> unique_constraint(:resource_id)
  end
end
