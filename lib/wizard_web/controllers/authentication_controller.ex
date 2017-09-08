defmodule WizardWeb.AuthenticationController do
  require Logger
  use WizardWeb, :controller

  alias Wizard.Sharepoint

  def signout(conn, _params) do
    conn
    |> WizardWeb.Guardian.Plug.sign_out()
    |> redirect(to: "/")
  end

  def signin(conn, _params) do
    state = SecureRandom.urlsafe_base64

    conn
    |> put_session(:state, state)
    |> redirect(external: Sharepoint.authorize_url(state))
  end

  def callback(conn, %{"code" => code, "state" => state}) do
    original_state = get_session(conn, :state)

    if original_state == state do
      case Sharepoint.authorize_sharepoints(code) do
        {:ok, %{user: user}} ->
          conn
          |> WizardWeb.Guardian.Plug.sign_in(user)
          |> put_flash(:info, "You are now signed in #{user.email}")
          |> redirect(to: "/")
        error ->
          Logger.error("There was an error signing in #{inspect error}")

          conn
          |> put_status(500)
          |> put_flash(:error, "There was a problem signing you in with Microsoft. This happens from time to time. Sorry. Please try again.")
          |> redirect(to: "/")
      end
    else
      conn
      |> put_flash(:error, "Something went wrong. Sorry about that. Maybe try again?")
      |> redirect(to: "/")
    end
  end
end
