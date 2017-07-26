defmodule Wizard.Sharepoint.Service do
  use Wizard.Schema
  alias Wizard.Sharepoint.{Authorization, Service, Site}

  schema "sharepoint_services" do
    has_many :authorizations, Authorization
    has_many :sites, Site

    field :resource_id, :string
    field :endpoint_uri, :string
    field :title, :string

    timestamps()
  end

  def changeset(%Service{} = service, attrs) do
    service
    |> cast(attrs, [:resource_id, :endpoint_uri, :title])
    |> validate_required([:resource_id, :endpoint_uri, :title])
    |> unique_constraint(:resource_id)
  end
end
