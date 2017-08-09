defmodule Wizard.Feeds.Feed do
  use Wizard.Schema
  alias Wizard.Sharepoint.Drive

  @type t :: %__MODULE__{}

  schema "feeds" do
    belongs_to :drive, Drive

    timestamps()
  end

  @spec changeset([drive: Drive.t]) :: Ecto.Changeset.t
  @spec changeset(t, [drive: Drive.t]) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = feed \\ %__MODULE__{}, [drive: drive]) do
    feed
    |> cast(%{}, [])
    |> foreign_key_constraint(:drive_id)
    |> put_assoc(:drive, drive)
  end
end
