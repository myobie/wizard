defmodule Wizard.PreviewGenerator do
  alias Wizard.PreviewGenerator.{Compare, Downloader, Sketch}

  def export_sketch(file),
    do: Sketch.export(file)

  def download(item, user),
    do: Downloader.download(item, user)

  def is_same_png?(first, second),
    do: Compare.is_same_png?(first, second)
end
