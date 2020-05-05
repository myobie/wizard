defmodule Wizard.Repo.Migrations.CreateFeedEvents do
  use Wizard.Migration

  def change do
    execute "CREATE EXTENSION intarray",
            "DROP EXTENSION intarray"

    create table(:feed_events) do
      add :type, :string, size: 64, null: false
      add :actor_ids, {:array, :int}, null: false
      add :subject_id, :int, null: false
      add :subject_type, :string, size: 64, null: false
      add :payload, :map, null: false, default: %{}
      add :grouping, :string, size: 64, null: false, default: "default"
      add :feed_id, references(:feeds, on_delete: :delete_all), null: false

      timestamps()
    end

    create constraint(:feed_events, :actor_ids_must_not_be_empty, check: "actor_ids <> '{}'")
    create constraint(:feed_events, :payload_must_be_an_object, check: "jsonb_typeof(payload) = 'object'")
    create unique_index(:feed_events, [:feed_id, :type, :subject_id, :subject_type, :grouping], name: :feed_events_unique_per_grouping_index)
  end
end
