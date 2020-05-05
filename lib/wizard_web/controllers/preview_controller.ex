defmodule WizardWeb.PreviewController do
  require Logger
  use WizardWeb, :controller
  alias Wizard.{Feeds, RemoteStorage, Repo}

  plug WizardWeb.EnsureAuthenticated

  @png_content_type "image/png"

  def show(conn, %{"feed_id" => _feed_id, "id" => id}) do
    with {:ok, preview} <- find_preview(id),
      {:ok, data} <- RemoteStorage.get_preview_raw_data(preview)
    do
      conn
      |> put_resp_header("content-type", @png_content_type)
      |> send_resp(200, data)
    else
      error ->
        Logger.error "error dealing with a preview #{inspect error}"
        conn
        |> put_status(500)
        |> text("something went wrong")
    end
  end

  defp find_preview(id) do
    case Repo.get(Feeds.Preview, id) do
      nil -> {:error, :not_found}
      preview -> {:ok, preview}
    end
  end
end
