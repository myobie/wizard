defmodule WizardWeb.PageController do
  use WizardWeb, :controller
  alias Wizard.Repo
  alias Wizard.PreviewGenerator.Getter
  alias Wizard.Feeds.Preview

  def index(conn, _params) do
    render conn, "index.html"
  end

  def feed(conn, _params) do
    events = Wizard.Feeds.all_events()
    render conn, "feed.html", events: events
  end

  def preview(conn, %{"id" => id}) do
    with {:ok, preview} <- find_preview(id),
         {:ok, %{body: body, content_type: content_type}} <- Getter.get_preview(preview) do
      conn
      |> put_resp_header("content-type", content_type)
      |> send_resp(200, body)
    end
  end

  defp find_preview(id) do
    case Repo.get(Preview, id) do
      nil -> {:error, :not_found}
      preview -> {:ok, preview}
    end
  end
end
