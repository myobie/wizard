defmodule Wizard.Repo.Migrations.CreateWizard.Sharepoint.Authorization do
  use Ecto.Migration

  def change do
    create table(:sharepoint_authorizations) do
      add :access_token, :string, null: false, size: 2048
      add :refresh_token, :string, null: false, size: 2048
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sharepoint_authorizations, [:user_id, :site_id], name: :authorizations_user_id_and_site_id_index)
  end
end
