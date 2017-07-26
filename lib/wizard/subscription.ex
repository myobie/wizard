defmodule Wizard.Subscriber.Subscription do
  use Wizard.Schema
  alias Wizard.{Sharepoint, User}

  schema "subscriptions" do
    belongs_to :user, User
    belongs_to :drive, Sharepoint.Drive

    timestamps()
  end

  def changeset do
    %__MODULE__{}
    |> cast([], [])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:drive_id)
    |> unique_constraint(:drive_id)
  end
end
