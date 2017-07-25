defmodule Wizard.Schema do
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      @timestamps_opts [type: :utc_datetime, usec: true]
      alias Ecto.Changeset
      import Changeset
    end
  end
end
