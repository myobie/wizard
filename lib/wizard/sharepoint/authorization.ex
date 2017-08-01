defmodule Wizard.Sharepoint.Authorization do
  use Wizard.Schema
  alias Wizard.Sharepoint.{Authorization, Service}
  alias Wizard.User

  @type t :: %__MODULE__{}

  schema "sharepoint_authorizations" do
    belongs_to :user, User
    belongs_to :service, Service

    field :access_token, :string
    field :refresh_token, :string

    timestamps()
  end

  @doc false
  def changeset(%Authorization{} = authorization, attrs) do
    authorization
    |> cast(attrs, [:access_token, :refresh_token])
    |> validate_required([:access_token, :refresh_token])
    |> validate_length([:access_token, :refresh_token], max: 2048)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:service_id)
    |> unique_constraint(:service_id, name: :authorizations_user_id_and_service_id_index)
  end

  @doc false
  def refresh_changeset(%Authorization{} = authorization, attrs) do
    authorization
    |> cast(attrs, [:access_token, :refresh_token])
    |> validate_required([:access_token, :refresh_token])
  end
end
