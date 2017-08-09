defmodule Wizard.Subscriber.Subscription do
  use Wizard.Schema
  alias Wizard.{Sharepoint, User}

  @type t :: %__MODULE__{}

  schema "subscriptions" do
    belongs_to :user, User
    belongs_to :drive, Sharepoint.Drive

    timestamps()
  end

  @spec changeset([drive: Sharepoint.Drive.t, user: User.t]) :: Ecto.Changeset.t
  @spec changeset(t, [drive: Sharepoint.Drive.t, user: User.t]) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = sub \\ %__MODULE__{}, [drive: drive, user: user]) do
    sub
    |> cast(%{}, [])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:drive_id)
    |> unique_constraint(:drive_id)
    |> put_assoc(:drive, drive)
    |> put_assoc(:user, user)
  end
end
