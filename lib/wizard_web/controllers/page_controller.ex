defmodule WizardWeb.PageController do
  use WizardWeb, :controller
  alias Wizard.Repo
  alias Wizard.RemoteStorage
  alias Wizard.Previews.PNG
  alias Wizard.Feeds.Preview

  def index(conn, _params) do
    render conn, "index.html"
  end

  def feed(conn, _params) do
    events = Wizard.Feeds.all_events()
    render conn, "feed.html", events: events
  end

  @png_content_type "image/png"

  def preview(conn, %{"id" => id}) do
    with {:ok, preview} <- find_preview(id),
         {:ok, png} <- RemoteStorage.get_preview(preview) do
      conn
      |> put_resp_header("content-type", @png_content_type)
      |> send_resp(200, PNG.to_binary(png))
    end
  end

  defp find_preview(id) do
    case Repo.get(Preview, id) do
      nil -> {:error, :not_found}
      preview -> {:ok, preview}
    end
  end
end
