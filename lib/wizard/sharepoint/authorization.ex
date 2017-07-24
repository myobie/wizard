defmodule Wizard.Sharepoint.Authorization do
  use Ecto.Schema
  @timestamps_opts [type: :utc_datetime, usec: true]
  import Ecto.Changeset
  alias Wizard.Sharepoint.{Authorization, User}

  schema "sharepoint_authorizations" do
    belongs_to :user, User

    field :access_token, :string
    field :refresh_token, :string
    field :resource_id, :string
    field :url, :string

    timestamps()
  end

  @doc false
  def changeset(%Authorization{} = authorization, attrs) do
    authorization
    |> cast(attrs, [:resource_id, :url, :access_token, :refresh_token])
    |> validate_required([:resource_id, :url, :access_token, :refresh_token])
    |> unique_constraint(:resource_id, name: :sharepoint_authorizations_resource_id_and_user_id_index)
    |> foreign_key_constraint(:user_id)
  end

  @doc false
  def refresh_changeset(%Authorization{} = authorization, attrs) do
    authorization
    |> cast(attrs, [:access_token, :refresh_token])
    |> validate_required([:access_token, :refresh_token])
  end

  def on_conflict_options(%Ecto.Changeset{} = changeset) do
    {_, access_token} = changeset |> fetch_field(:access_token)
    {_, refresh_token} = changeset |> fetch_field(:refresh_token)
    [access_token: access_token, refresh_token: refresh_token]
  end
end
