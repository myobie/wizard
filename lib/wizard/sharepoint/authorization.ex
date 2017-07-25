defmodule Wizard.Sharepoint.Authorization do
  use Wizard.Schema
  alias Wizard.Sharepoint.{Authorization, Site, User}

  schema "sharepoint_authorizations" do
    belongs_to :user, User
    belongs_to :site, Site

    field :access_token, :string
    field :refresh_token, :string

    timestamps()
  end

  @doc false
  def changeset(%Authorization{} = authorization, attrs) do
    authorization
    |> cast(attrs, [:access_token, :refresh_token])
    |> validate_required([:access_token, :refresh_token])
    |> unique_constraint(:site_id, name: :authorizations_user_id_and_site_id_index)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:site_id)
  end

  @doc false
  def refresh_changeset(%Authorization{} = authorization, attrs) do
    authorization
    |> cast(attrs, [:access_token, :refresh_token])
    |> validate_required([:access_token, :refresh_token])
  end

  @doc false
  def on_conflict_options(%Changeset{} = changeset) do
    {_, access_token} = changeset |> fetch_field(:access_token)
    {_, refresh_token} = changeset |> fetch_field(:refresh_token)
    [access_token: access_token, refresh_token: refresh_token]
  end
end
