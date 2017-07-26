defmodule Wizard.Subscription do
  use Wizard.Schema
  alias Wizard.{Sharepoint, Subscription, User}


  schema "subscriptions" do
    belongs_to :user, User
    belongs_to :sharepoint_drive, Sharepoint.Drive

    timestamps()
  end

  def changeset(%Subscription{} = subscription, attrs) do
    subscription
    |> cast(attrs, [])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:sharepoint_drive_id)
    |> unique_constraint(:sharepoint_drive_id)
  end
end
