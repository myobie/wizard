defmodule Wizard.Feeds.Preview do
  use Wizard.Schema
  alias Wizard.Feeds.{Event, Preview}

  @type t :: %__MODULE__{}

  schema "feed_previews" do
    belongs_to :event, Event

    field :name, :string
    field :width, :integer
    field :height, :integer
    field :path, :string
    field :sizes, {:array, :string}

    timestamps()
  end

  @spec changeset(map, [event: Event.t]) :: Ecto.Changeset.t
  @spec changeset(t, map, [event: Event.t]) :: Ecto.Changeset.t
  def changeset(%Preview{} = preview \\ %Preview{}, attrs, [event: event]) do
    preview
    |> cast(attrs, [:name, :width, :height, :path, :sizes])
    |> validate_required([:name, :width, :height, :path, :sizes])
    |> validate_length(:name, max: 255)
    |> validate_length(:path, max: 2048)
    |> check_constraint(:sizes, name: :sizes_must_not_be_empty)
    |> foreign_key_constraint(:event_id)
    |> put_assoc(:event, event)
  end
end
