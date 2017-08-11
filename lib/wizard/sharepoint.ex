defmodule Wizard.Sharepoint do
  require Logger

  import Ecto.Query, warn: false
  import Ecto.Changeset, only: [fetch_field: 2]
  alias Ecto.Multi
  alias Wizard.Repo

  alias Wizard.{Feeds, User}
  alias Wizard.Feeds.Feed
  alias Wizard.Sharepoint.{Authorization, Drive, Events, Item, Service, Site}
  alias Wizard.Sharepoint.Api.{Authentication, Sites}

  @type transaction_result :: {:ok, any} | {:error, any} | {:error, any, any, any}
  @type parents :: %{optional(String.t) => Item.t}

  @spec authorize_url(String.t) :: String.t
  def authorize_url(state),
    do: Authentication.authorize_url(state)

  @spec authorize_sharepoints(String.t) :: transaction_result
  def authorize_sharepoints(code) do
    case Authentication.authorize_sharepoints(code) do
      {:ok, user_info, services_info, authorizations_info} ->
        upsert_user_and_services(user_info, services_info, authorizations_info)
      error ->
        error
    end
  end

  @spec upsert_user_and_services(map, [map], [map]) :: transaction_result
  def upsert_user_and_services(user_info, services_info, authorizations_info) do
    build_upsert_user_and_services(user_info, services_info, authorizations_info)
    |> Repo.transaction()
  end

  @spec reauthorize(Service.t, User.t) :: {:ok, Authorization.t} | {:error, Ecto.Changeset.t} | {:error, atom}
  def reauthorize(%Service{} = service, %User{} = user) do
    case Repo.get_by(Authorization, service_id: service.id, user_id: user.id) do
      nil -> {:error, :authorization_not_found}
      auth ->
        auth = %{auth | service: service}
        reauthorize(auth)
    end
  end

  @spec reauthorize(Authorization.t) :: {:ok, Authorization.t} | {:error, Ecto.Changeset.t} | {:error, atom}
  def reauthorize(%Authorization{service: %Service{} = service} = auth) do
    case Authentication.reauthorize_sharepoint_service(service, auth.refresh_token) do
      {:ok, attrs} ->
        Authorization.refresh_changeset(auth, attrs)
        |> Repo.update()
      error ->
        error
    end
  end

  @spec remotely_search_sites(Service.t, User.t, String.t) :: [map] | {:error, atom}
  def remotely_search_sites(service, user, query) do
    case Repo.get_by(Authorization, service_id: service.id, user_id: user.id) do
      nil -> {:error, :unauthorized}
      auth -> Sites.search(auth, service, query)
    end
  end

  @spec remotely_list_drives(Site.t, User.t) :: [map] | {:error, atom}
  def remotely_list_drives(site, user) do
    site = Repo.preload(site, :service)

    case Repo.get_by(Authorization, service_id: site.service.id, user_id: user.id) do
      nil -> {:error, :unauthorized}
      auth -> Sites.drives(auth, site)
    end
  end

  @site_conflict_query from s in Site,
                         update: [set: [
                           url: fragment("EXCLUDED.url"),
                           hostname: fragment("EXCLUDED.hostname"),
                           title: fragment("EXCLUDED.title"),
                           description: fragment("EXCLUDED.description")
                         ]]

  @site_conflict_options [on_conflict: @site_conflict_query,
                          conflict_target: :remote_id]

  @spec upsert_site(map, [service: Service.t]) :: {:ok, Site.t} | {:error, Ecto.Changeset.t}
  def upsert_site(attrs, [service: service]) do
    Site.changeset(attrs, service: service)
    |> Repo.insert(@site_conflict_options)
  end

  @drive_conflict_query from d in Drive,
                          update: [set: [
                            name: fragment("EXCLUDED.name"),
                            type: fragment("EXCLUDED.type"),
                            url: fragment("EXCLUDED.url"),
                            delta_link: fragment("EXCLUDED.delta_link"),
                          ]]

  @drive_conflict_options [on_conflict: @drive_conflict_query,
                           conflict_target: :remote_id]

  @spec upsert_drive(map, [site: Site.t]) :: {:ok, Drive.t} | {:error, Ecto.Changeset.t}
  def upsert_drive(attrs, [site: site]) do
    Drive.changeset(attrs, site: site)
    |> Repo.insert(@drive_conflict_options)
  end

  @spec update_drive(Drive.t, [delta_link: String.t]) :: {:ok, Drive.t} | {:error, Ecto.Changeset.t}
  def update_drive(drive, [delta_link: delta_link]) do
    drive
    |> Drive.update_delta_link_changeset(delta_link)
    |> Repo.update()
  end

  @user_conflict_query from u in User,
                         update: [set: [
                           name: fragment("EXCLUDED.name")
                         ]]

  @user_conflict_options [on_conflict: @user_conflict_query,
                          conflict_target: :email]

  defp upsert_user(multi, user_info) do
    changeset = User.changeset(user_info)
    Multi.insert(multi, :user, changeset, @user_conflict_options)
  end

  @service_conflict_query from s in Service,
                            update: [set: [
                              title: fragment("EXCLUDED.title")
                            ]]

  @service_conflict_options [on_conflict: @service_conflict_query,
                             conflict_target: :resource_id]

  @spec upsert_services([map]) :: {:ok, [Service.t]} | {:error, any}
  defp upsert_services(infos) do
    case Multi.new |> upsert_services(infos) |> Repo.transaction() do
      {:ok, changes} ->
        services = for {{:service, _}, service} <- changes, do: service
        {:ok, services}
      error ->
        error
    end
  end

  @spec upsert_services(Multi.t, [map]) :: Multi.t
  defp upsert_services(multi, [info | infos]) do
    changeset = Service.changeset(info)
    {_, resource_id} = fetch_field(changeset, :resource_id)
    name = {:service, resource_id}

    multi
    |> Multi.insert(name, changeset, @service_conflict_options)
    |> upsert_services(infos)
  end

  defp upsert_services(multi, []), do: multi

  @spec upsert_authorizations(%{services: [Service.t], user: User.t}, [map]) :: {:ok, [Authorization.t]} | {:error, any}
  defp upsert_authorizations(%{services: services, user: user}, infos) do
    case Multi.new |> upsert_authorizations(user, services, infos) |> Repo.transaction() do
      {:ok, changes} ->
        auths = for {{:authorization, _}, authorization} <- changes, do: authorization
        {:ok, auths}
      error ->
        error
    end
  end

  @authorization_conflict_query from a in Authorization,
                                  update: [set: [
                                    access_token: fragment("EXCLUDED.access_token"),
                                    refresh_token: fragment("EXCLUDED.refresh_token")
                                  ]]

  @authorization_conflict_options [on_conflict: @authorization_conflict_query,
                                   conflict_target: [:user_id, :service_id]]

  @spec upsert_authorizations(Multi.t, User.t, [Service.t], [map]) :: Multi.t
  defp upsert_authorizations(multi, user, services, [info | infos]) do
    case Enum.find(services, &(&1.resource_id == Map.get(info, :resource_id))) do
      nil ->
        Multi.error(multi,
                    {:authorization, SecureRandom.hex()},
                    :missing_service_for_authorization_resource_id)
      service ->
        name = {:authorization, service.resource_id}

        changeset = Authorization.changeset(info, user: user, service: service)

        multi
        |> Multi.insert(name, changeset, @authorization_conflict_options)
        |> upsert_authorizations(user, services, infos)
    end
  end

  defp upsert_authorizations(multi, _, _, []), do: multi

  @spec build_upsert_user_and_services(map, [map], [map]) :: Multi.t
  defp build_upsert_user_and_services(user_info, services_info, authorizations_info) do
    Multi.new
    |> upsert_user(user_info)
    |> Multi.run(:services, fn _ -> upsert_services(services_info) end)
    |> Multi.run(:authorizations, &(upsert_authorizations(&1, authorizations_info)))
  end

  @spec upsert_remote_item(map, [drive: Drive.t, feed: Feed.t, parents: parents]) :: {:ok, any, parents} | {:error, any} | {:error, any, any, any}
  def upsert_remote_item(info, [drive: drive, feed: feed, parents: parents]) do
    attrs = Item.parse_remote(info)

    res = Multi.new
          |> insert_user_for_item_if_not_exists(attrs)
          |> upsert_item_with_parent(attrs, drive: drive, parents: parents)
          |> upsert_item_event(feed: feed)
          |> Repo.transaction()

    case res do
      {:ok, %{item: item} = result} ->
        {:ok, result, Map.put(parents, item.remote_id, item)}
      error ->
        error
    end
  end

  @other_user_conflict_query from u in User,
                               update: [set: [
                                 name: fragment("EXCLUDED.name")
                               ]]

  @other_user_conflict_options [on_conflict: @other_user_conflict_query,
                                conflict_target: :email,
                                returning: true]

  @spec insert_user_for_item_if_not_exists(Multi.t, map) :: Multi.t
  defp insert_user_for_item_if_not_exists(multi, %{user: nil}),
    do: multi

  defp insert_user_for_item_if_not_exists(multi, %{user: user_attrs}) do
    Multi.run(multi, :user, fn _ ->
      User.changeset(user_attrs)
      |> Repo.insert(@other_user_conflict_options)
    end)
  end

  @spec upsert_item_with_parent(Multi.t, map, [drive: Drive.t, parents: parents]) :: Multi.t
  defp upsert_item_with_parent(multi, %{parent_remote_id: nil} = item_attrs, [drive: drive, parents: _parents]) do
    multi
    |> upsert_item(item_attrs, drive: drive)
  end

  defp upsert_item_with_parent(multi, item_attrs, [drive: drive, parents: parents]) do
    case Map.fetch(parents, item_attrs.parent_remote_id) do
      {:ok, parent} ->
        multi
        |> upsert_item(item_attrs, drive: drive, parent: parent)
      :error ->
        Logger.error "cannot find parent for #{inspect({:item, item_attrs})}"
        multi
        |> Multi.error(:item, :cannot_find_parent_for_item)
    end
  end

  @spec item_changeset(map, [drive: Drive.t, parent: Item.t] | [drive: Drive.t]) :: Ecto.Changeset.t
  defp item_changeset(attrs, [drive: drive]),
    do: Item.changeset(attrs, drive: drive)

  defp item_changeset(attrs, [drive: drive, parent: parent]),
    do: Item.changeset(attrs, drive: drive, parent: parent)

  @item_conflict_query from i in Item,
                         update: [set: [
                           name: fragment("EXCLUDED.name"),
                           type: fragment("EXCLUDED.type"),
                           last_modified_at: fragment("EXCLUDED.last_modified_at"),
                           size: fragment("EXCLUDED.size"),
                           url: fragment("EXCLUDED.url"),
                           parent_id: fragment("EXCLUDED.parent_id"),
                           updated_at: fragment("EXCLUDED.inserted_at")
                         ]]

  @item_conflict_options [on_conflict: @item_conflict_query,
                          conflict_target: [:remote_id, :drive_id],
                          returning: true]

  @spec upsert_item(Multi.t, map, [drive: Drive.t, parent: Item.t] | [drive: Drive.t]) :: Multi.t
  defp upsert_item(multi, attrs, opts) do
    Multi.run(multi, :item, fn _ ->
      item_changeset(attrs, opts)
      |> Repo.insert(@item_conflict_options)
    end)
  end

  @spec upsert_item_event(Multi.t, [feed: Feed.t]) :: Multi.t
  defp upsert_item_event(multi, [feed: feed]) do
    Multi.run(multi, :event, &upsert_item_event_multi_body(&1, feed))
  end

  defp upsert_item_event_multi_body(%{item: item, user: user}, %Feed{} = feed) do
    if Events.should_emit_event?(item, user) do
      item_event_type(item)
      |> Events.prepare_item_event(item, user)
      |> Keyword.merge([feed: feed])
      |> Feeds.upsert_event()
    else
      {:ok, nil}
    end
  end
  defp upsert_item_event_multi_body(_, _), do: {:ok, nil}

  @spec item_event_type(Item.t) :: :create | :update | :delete
  defp item_event_type(%Item{} = item) do
    cond do
      not is_nil(item.deleted_at) -> :delete
      item.updated_at > item.inserted_at -> :update
      item.updated_at == item.inserted_at -> :create
      true -> :create # NOTE: what should we do here?
    end
  end

  @spec discover_parents([map], [drive: Drive.t]) :: parents
  def discover_parents([], _), do: %{}

  def discover_parents(infos, [drive: %{id: drive_id}]) do
    parent_ids = infos
                 |> Enum.map(&Item.assoc_remote_parent_remote_id/1)
                 |> Enum.drop_while(&is_nil/1)

    query = from i in Item,
              where: i.remote_id in ^parent_ids,
              where: i.drive_id == ^drive_id

    items = query |> Repo.all()

    for item <- items, into: %{}, do: {item.remote_id, item}
  end

  @spec upsert_or_delete_remote_items([map], [drive: Drive.t, feed: Feed.t]) :: transaction_result
  def upsert_or_delete_remote_items(infos, [drive: drive, feed: feed]) do
    deletes = for info <- infos, Map.has_key?(info, "deleted"), do: info
    upserts = infos -- deletes
    parents = discover_parents(upserts, drive: drive)

    delete_remote_items(deletes, drive: drive, feed: feed)
    upsert_remote_items(upserts, drive: drive, feed: feed, parents: parents)
  end

  @spec delete_remote_items([map], [drive: Drive.t, feed: Feed.t]) :: {integer, nil | [term]}
  defp delete_remote_items([], _), do: {0, []}

  # TODO: loop through and delete each one so we can do an
  # event for it after determining how to know the actor
  defp delete_remote_items(infos, [drive: %{id: drive_id}, feed: _feed]) do
    now = DateTime.utc_now()
    remote_ids = for info <- infos, Map.has_key?(info, "id"), do: info["id"]
    query = from i in Item,
              where: i.remote_id in ^remote_ids,
              where: i.drive_id == ^drive_id,
              update: [set: [deleted_at: ^now]]

    Repo.update_all(query, [])
  end

  @spec upsert_remote_items([map], [drive: Drive.t, feed: Feed.t, parents: parents]) :: :ok | {:error, any}
  defp upsert_remote_items([info | infos], [drive: drive, feed: feed, parents: parents]) do
    case upsert_remote_item(info, drive: drive, feed: feed, parents: parents) do
      {:ok, _, parents} ->
        upsert_remote_items(infos, drive: drive, feed: feed, parents: parents) # NOTE: recurse
      {:error, _} = error ->
        error
      {:error, name, msg, info} ->
        {:error, {name, msg, info}}
    end
  end

  defp upsert_remote_items([], _), do: :ok # NOTE: done
end
