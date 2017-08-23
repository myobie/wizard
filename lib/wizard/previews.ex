defmodule Wizard.Previews do
  alias Wizard.Previews.{Downloader, Inserter, Sketch}

  def export_sketch_artboards_to_files(download),
    do: Sketch.export(download)

  def download(event),
    do: Downloader.download(event)

  def insert_previews_for_uploads(uploads),
    do: Inserter.insert_previews_for_uploads(uploads)
end
