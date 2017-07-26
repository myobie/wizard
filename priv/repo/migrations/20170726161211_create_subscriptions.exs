defmodule Wizard.Repo.Migrations.CreateSubscriptions do
  use Wizard.Migration

  def change do
    create table(:subscriptions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :sharepoint_drive_id, references(:sharepoint_drives, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:subscriptions, [:user_id])
    create unique_index(:subscriptions, [:sharepoint_drive_id])
  end
end
