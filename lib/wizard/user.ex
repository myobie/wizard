defmodule Wizard.User do
  use Wizard.Schema
  alias Wizard.User
  alias Wizard.Sharepoint.Authorization

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
    |> unique_constraint(:email)
  end

  @doc false
  def on_conflict_options(%Changeset{} = changeset) do
    {_, name} = changeset |> fetch_field(:name)
    [name: name]
  end
end
