defmodule WizardWeb.PageController do
  use WizardWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end

  def feed(conn, _params) do
    events = Wizard.Feeds.all_events()
    render conn, "feed.html", events: events
  end
end
