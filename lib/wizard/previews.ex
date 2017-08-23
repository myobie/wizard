defmodule Wizard.Previews do
  alias Wizard.Previews.{Compare, Downloader, Inserter, Sketch}

  def download(event),
    do: Downloader.download(event)

  def export_sketch_artboards_to_files(download),
    do: Sketch.export(download)

  def filter_unchanged_exports(files),
    do: Compare.filter_unchanged_exports(files)

  def insert_previews_for_uploads(uploads),
    do: Inserter.insert_previews_for_uploads(uploads)
end
