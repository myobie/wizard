defmodule Wizard.Repo.Migrations.CreateWizard.User do
  use Wizard.Migration

  def change do
    create table(:users) do
      add :name, :string, null: false
      add :email, :string, null: false

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end