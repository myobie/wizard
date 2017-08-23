defmodule Wizard.Previews.ExportedFile do
  alias Wizard.Previews.Download
  alias Wizard.Feeds

  defstruct uuid: "",
            name: "",
            path: "",
            download: nil,
            meta: %{}

  @type t :: %__MODULE__{}

  @spec remote_path(t) :: String.t
  def remote_path(%__MODULE__{name: name, download: %Download{event: %Feeds.Event{id: event_id}}}),
    do: "/events/#{event_id}/previews/#{name}"
end
