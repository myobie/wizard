defmodule Wizard.Repo.Migrations.CreateFeedPreviews do
  use Wizard.Migration

  def change do
    create table(:feed_previews) do
      add :name, :string, null: false
      add :width, :integer, null: false
      add :height, :integer, null: false
      add :sizes, {:array, :string}, null: false
      add :path, :string, size: 2048, null: false
      add :event_id, references(:feed_events, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:feed_previews, [:event_id])
    create constraint(:feed_previews, :sizes_must_not_be_empty, check: "sizes <> '{}'")

    alter table(:feed_events) do
      add :preview_state, :string, size: 64, null: false, default: "pending"
    end
  end
end
