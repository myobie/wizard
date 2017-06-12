defmodule Wizard.Repo.Migrations.CreateWizard.Sharepoint.Drive do
  use Ecto.Migration

  def change do
    create table(:sharepoint_drives) do
      add :remote_id, :string, null: false
      add :name, :string, null: false
      add :url, :string, null: false
      add :type, :string, null: false
      add :delta_link, :string, null: true
      add :authorization_id, references(:sharepoint_authorizations, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:sharepoint_drives, [:remote_id])
    create index(:sharepoint_drives, [:authorization_id])
    create unique_index(:sharepoint_drives, [:authorization_id, :remote_id], name: :sharepoint_drives_authorization_id_and_remote_id_index)
  end
end
