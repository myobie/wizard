defmodule WizardWeb.PageController do
  use WizardWeb, :controller

  plug WizardWeb.GuardianNoauthPipeline

  def index(conn, _params) do
    render conn, "index.html"
  end
end
