defmodule Wizard.Repo.Migrations.CreateWizard.Sharepoint.Service do
  use Wizard.Migration

  def change do
    create table(:sharepoint_services) do
      add :resource_id, :string, null: false
      add :endpoint_uri, :string, null: false
      add :title, :string, null: false

      timestamps()
    end

    create unique_index(:sharepoint_services, [:resource_id])
  end
end
