defmodule Wizard.Sharepoint.Site do
  use Wizard.Schema
  alias Wizard.Sharepoint.{Authorization, Site}

  schema "sharepoint_sites" do
    has_many :authorizations, Authorization

    field :remote_id, :string
    field :url, :string
    field :hostname, :string
    field :title, :string
    field :description, :string

    timestamps()
  end

  @doc false
  def changeset(%Site{} = site, attrs) do
    site
    |> cast(attrs, [:remote_id, :hostname, :title, :url, :description])
    |> validate_required([:remote_id, :hostname, :title, :url])
    |> unique_constraint(:remote_id)
  end

  @doc false
  def on_conflict_options(%Changeset{} = changeset) do
    {_, hostname} = changeset |> fetch_field(:hostname)
    {_, title} = changeset |> fetch_field(:title)
    {_, url} = changeset |> fetch_field(:url)
    {_, description} = changeset |> fetch_field(:description)
    [hostname: hostname, title: title, url: url, description: description]
  end
end
