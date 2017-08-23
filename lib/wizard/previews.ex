defmodule Wizard.Previews do
  require Logger
  alias Wizard.Previews.{Downloader, Inserter, Sketch}

  def export_sketch(path, event),
    do: Sketch.export(path, event)

  def download(subject, user),
    do: Downloader.download(subject, user)

  def insert_previews_for_files(files),
    do: Inserter.insert_previews_for_files(files)
end
