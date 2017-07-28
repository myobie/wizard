defmodule Wizard.Schema do
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      @timestamps_opts [type: :utc_datetime, usec: true]
      alias Ecto.Changeset
      import Changeset
      import unquote(__MODULE__)
    end
  end

  defmacro deleted_at do
    quote do
      field :deleted_at, :utc_datetime
    end
  end
end
