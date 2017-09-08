defmodule WizardWeb.FeedController do
  use WizardWeb, :controller
  alias Wizard.Feeds

  def show(conn, %{"id" => id}) do
    events = Feeds.all_events(id)
    render conn, "feed.html", feed_id: id, events: events
  end
end
