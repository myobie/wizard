defmodule Wizard.Sharepoint.User do
  use Ecto.Schema
  @timestamps_opts [type: :utc_datetime, usec: true]
  import Ecto.Changeset
  alias Wizard.Sharepoint.{Authorization, User}

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

  def on_conflict_options(%Ecto.Changeset{} = changeset) do
    {_, name} = changeset |> fetch_field(:name)
    [name: name]
  end
end
