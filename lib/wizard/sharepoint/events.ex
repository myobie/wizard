defmodule Wizard.Sharepoint.Events do
  alias Wizard.Sharepoint.Item
  alias Wizard.{Feeds, User}

  @extensions ~w(.sketch)

  @spec should_emit_event?(Item.t, User.t) :: boolean
  def should_emit_event?(%Item{name: name, type: "file"}, _user),
    do: Path.extname(name) |> Enum.member?(@extensions)

  def should_emit_event?(_item, _user), do: false

  @spec pad(non_neg_integer) :: String.t
  defp pad(num) when num < 10, do: "0#{num}"
  defp pad(num),               do: to_string(num)

  @spec grouping_by_hour() :: String.t
  defp grouping_by_hour do
    now = DateTime.utc_now()
    "#{now.year}-#{pad now.month}-#{pad now.day}-#{pad now.hour}"
  end

  @spec prepare_item_event(atom, Item.t, User.t) :: Feeds.event_info
  def prepare_item_event(type, item, user) do
    [type: "file.#{type}",
     actor: user,
     subject: %{
       id: item.id,
       type: "sharepoint.item"
     },
     payload: %{
       name: item.name,
       url: item.url
     },
     grouping: grouping_by_hour()]
  end
end
