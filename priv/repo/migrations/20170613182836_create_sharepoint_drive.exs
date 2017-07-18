defmodule Wizard.Repo.Migrations.CreateWizard.Sharepoint.Drive do
  use Ecto.Migration

  def change do
    create table(:sharepoint_drives) do
      add :remote_id, :string, null: false
      add :name, :string, null: false
      add :url, :string, null: false
      add :type, :string, null: false
      add :delta_link, :string, null: true
      add :site_id, references(:sharepoint_sites, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:sharepoint_drives, [:remote_id])
    create index(:sharepoint_drives, [:site_id])
  end
end
