defmodule Wizard.Sharepoint.Site do
  use Ecto.Schema
  import Ecto.Changeset
  alias Wizard.Sharepoint.{Authorization, Site}

  schema "sites" do
    belongs_to :authorization, Authorization

    field :description, :string
    field :hostname, :string
    field :remote_id, :string
    field :title, :string
    field :url, :string

    timestamps()
  end

  @doc false
  def changeset(%Site{} = site, attrs) do
    site
    |> cast(attrs, [:remote_id, :hostname, :title, :url, :description])
    |> validate_required([:remote_id, :hostname, :title, :url])
    |> foreign_key_constraint(:authorization_id)
    |> unique_constraint(:remote_id)
  end
end
