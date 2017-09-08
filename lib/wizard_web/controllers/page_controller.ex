defmodule WizardWeb.PageController do
  use WizardWeb, :controller

  plug WizardWeb.LoadAuthentication

  def index(conn, _params) do
    render conn, "index.html"
  end
end
