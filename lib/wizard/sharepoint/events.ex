defmodule Wizard.Sharepoint.Events do
  alias Wizard.Sharepoint.Item
  alias Wizard.{Feeds, User}

  @name_regex ~r/\A.*\.sketch$\z/

  @spec should_emit_event?(Item.t, User.t) :: boolean
  def should_emit_event?(%Item{name: name}, _user) do
    Regex.match? @name_regex, name
  end

  @spec prepare_item_create_event(Item.t, User.t) :: Feeds.event_info
  def prepare_item_create_event(item, user),
    do: prepare_item_event(:create, item, user)

  @spec prepare_item_update_event(Item.t, User.t) :: Feeds.event_info
  def prepare_item_update_event(item, user),
    do: prepare_item_event(:update, item, user)

  @spec prepare_item_delete_event(Item.t, User.t) :: Feeds.event_info
  def prepare_item_delete_event(item, user),
    do: prepare_item_event(:delete, item, user)

  @spec pad(non_neg_integer) :: String.t
  defp pad(num) when num < 10, do: "0#{num}"
  defp pad(num), do: to_string(num)

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
