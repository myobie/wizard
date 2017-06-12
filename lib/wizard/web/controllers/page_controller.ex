defmodule Wizard.Web.PageController do
  use Wizard.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
