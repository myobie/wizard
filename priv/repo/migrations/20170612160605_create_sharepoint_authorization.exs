defmodule Wizard.Repo.Migrations.CreateWizard.Sharepoint.Authorization do
  use Ecto.Migration

  def change do
    create table(:sharepoint_authorizations) do
      add :resource_id, :string, null: false
      add :url, :string, null: false
      add :access_token, :string, null: false, size: 2048
      add :refresh_token, :string, null: false, size: 2048
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:sharepoint_authorizations, [:user_id])
    create unique_index(:sharepoint_authorizations, [:resource_id, :user_id], name: :sharepoint_authorizations_resource_id_and_user_id_index)
  end
end
