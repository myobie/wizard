defmodule Wizard.PreviewGenerator.ExportedFile do
  defstruct uuid: "",
            name: "",
            path: "",
            upload_uri: "",
            event: nil,
            preview: nil,
            meta: %{}

  @type t :: %__MODULE__{}

  @spec remote_path(t) :: String.t
  def remote_path(file),
    do: "/events/#{file.event.id}/previews/#{file.name}"
end
