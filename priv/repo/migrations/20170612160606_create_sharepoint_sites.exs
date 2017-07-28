defmodule Wizard.Repo.Migrations.CreateWizard.Sharepoint.Site do
  use Wizard.Migration

  def change do
    create table(:sharepoint_sites) do
      add :remote_id, :string, null: false
      add :url, :string, null: false
      add :hostname, :string, null: false
      add :title, :string, null: false
      add :description, :string
      add :service_id, references(:sharepoint_services, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:sharepoint_sites, [:remote_id])
  end
end
