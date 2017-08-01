defmodule Wizard.User do
  use Wizard.Schema
  alias Wizard.User
  alias Wizard.Sharepoint.Authorization

  @type t :: %__MODULE__{}

  schema "users" do
    has_many :authorizations, Authorization

    field :email, :string
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(%User{} = user, attrs) do
    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
    |> validate_length(:name, max: 255)
    |> validate_length(:email, max: 2048)
    |> unique_constraint(:email)
  end

  @doc false
  def on_conflict_options(%Changeset{} = changeset) do
    changeset
    |> fetch_fields([:name])
  end
end
