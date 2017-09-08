defmodule WizardWeb.FeedController do
  use WizardWeb, :controller
  alias Wizard.Feeds

  plug WizardWeb.GuardianAuthPipeline

  def show(conn, %{"id" => id}) do
    events = Feeds.all_events(id)
    render conn, "show.html", feed_id: id, events: events
  end
end
