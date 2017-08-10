defmodule Wizard.Repo.Migrations.CreateFeeds do
  use Wizard.Migration

  def change do
    create table(:feeds) do
      add :drive_id, references(:sharepoint_drives, on_delete: :nothing), null: false

      timestamps()
    end

    create unique_index(:feeds, [:drive_id])
  end
end
