defmodule WizardWeb.FeedController do
  use WizardWeb, :controller
  alias Wizard.{Feeds, Repo, Sharepoint}

  plug WizardWeb.EnsureAuthenticated

  def show(conn, %{"id" => id}) do
    if authorized?(conn, id) do
      events = Feeds.all_events(id)
      render conn, "show.html", feed_id: id, events: events
    else
      conn
      |> put_flash(:error, "Coulnd't find that feed")
      |> redirect(to: "/")
    end
  end

  defp authorized?(conn, feed_id) do
    with user when not is_nil(user) <- current_resource(conn),
      feed when not is_nil(feed) <- get_feed(feed_id),
      service_id when not is_nil(service_id) <- get_service_id(feed),
      auth when not is_nil(auth) <- get_authorization(user.id, service_id)
    do
      true
    else
      _ -> false
    end
  end

  defp current_resource(conn),
    do: WizardWeb.Guardian.Plug.current_resource(conn)

  defp get_feed(id),
    do: Repo.get(Feeds.Feed, id)

  defp get_service_id(feed) do
    feed = Repo.preload(feed, drive: :site)
    feed.drive.site.service_id
  end

  defp get_authorization(user_id, service_id),
    do: Repo.get_by(Sharepoint.Authorization, user_id: user_id, service_id: service_id)
end
