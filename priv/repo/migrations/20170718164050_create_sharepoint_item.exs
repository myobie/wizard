defmodule Wizard.Repo.Migrations.CreateWizard.Sharepoint.Item do
  use Ecto.Migration

  def change do
    create table(:sharepoint_items) do
      add :remote_id, :string, null: false
      add :name, :string, null: false
      add :type, :string, null: false
      add :last_modified_at, :utc_datetime, null: false
      add :size, :bigint, null: false
      add :url, :string, null: false
      add :full_path, :string, null: false
      add :parent_id, references(:sharepoint_items, on_delete: :nilify_all), null: true
      add :drive_id, references(:sharepoint_drives, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:sharepoint_drives, [:remote_id, :type], name: :sharepoint_items_remote_id_and_type_index)
  end
end
