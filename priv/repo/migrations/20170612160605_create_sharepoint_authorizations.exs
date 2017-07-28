defmodule Wizard.Repo.Migrations.CreateWizard.Sharepoint.Authorization do
  use Wizard.Migration

  def change do
    create table(:sharepoint_authorizations) do
      add :access_token, :string, null: false, size: 2048
      add :refresh_token, :string, null: false, size: 2048
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :service_id, references(:sharepoint_services, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:sharepoint_authorizations, [:user_id, :service_id], name: :authorizations_user_id_and_service_id_index)
  end
end
