defmodule Wizard.Repo.Migrations.CreateWizard.Sharepoint.Site do
  use Ecto.Migration

  def change do
    create table(:sharepoint_sites) do
      add :remote_id, :string, null: false
      add :hostname, :string, null: false
      add :title, :string, null: false
      add :url, :string, null: false
      add :description, :string
      add :authorization_id, references(:sharepoint_authorizations, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:sharepoint_sites, [:remote_id])
    create index(:sharepoint_sites, [:authorization_id])
  end
end
