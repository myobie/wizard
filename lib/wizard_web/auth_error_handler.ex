defmodule WizardWeb.AuthErrorHandler do
  require Logger
  import Phoenix.Controller

  def auth_error(conn, reason, _opts) do
    Logger.error "Auth error: #{inspect reason}"

    conn
    |> put_flash(:error, "You must sign in")
    |> redirect(to: "/")
  end
end
