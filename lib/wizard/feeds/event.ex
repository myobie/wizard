defmodule Wizard.Feeds.Event do
  use Wizard.Schema
  alias Wizard.Feeds.{Event, Feed, Preview}

  @type t :: %__MODULE__{}

  schema "feed_events" do
    belongs_to :feed, Feed
    has_many :previews, Preview, foreign_key: :event_id

    field :type, :string
    field :actor_ids, {:array, :integer}
    field :subject_id, :integer
    field :subject_type, :string
    field :payload, :map, default: %{}
    field :grouping, :string, default: "default"
    field :preview_state, :string, default: "pending"

    field :actors, {:array, :map}, virtual: true
    field :subject, :map, virtual: true
    field :subscription, :map, virtual: true

    timestamps()
  end

  @spec changeset(map, [feed: Feed.t]) :: Ecto.Changeset.t
  @spec changeset(t, map, [feed: Feed.t]) :: Ecto.Changeset.t
  def changeset(%Event{} = event \\ %Event{}, attrs, [feed: feed]) do
    event
    |> cast(attrs, [:type, :actor_ids, :subject_id, :subject_type, :payload, :grouping])
    |> validate_required([:type, :actor_ids, :subject_id, :subject_type, :payload, :grouping])
    |> validate_length([:type, :subject_type, :grouping], max: 64)
    |> validate_inclusion(:preview_state, ["pending", "complete", "failed"])
    |> check_constraint(:actor_ids, name: :actor_ids_must_not_be_empty)
    |> check_constraint(:subject, name: :payload_must_be_an_object)
    |> foreign_key_constraint(:feed_id)
    |> unique_constraint(:subject, name: :feed_events_unique_per_grouping_index)
    |> put_assoc(:feed, feed)
  end
end
