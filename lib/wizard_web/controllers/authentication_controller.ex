defmodule WizardWeb.AuthenticationController do
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
        {:ok, %{user: user} = results} ->
          conn
          |> WizardWeb.Guardian.Plug.sign_in(user)
          |> text("worked:\n\n#{inspect(results)}")
        error ->
          conn
          |> put_status(500)
          |> text("something didn't work:\n\n#{inspect(error)}")
      end
    else
      conn |> text("state didn't match")
    end
  end
end
