defmodule Wizard.Sharepoint do
  require Logger

  import Ecto.Query, warn: false
  import Ecto.Changeset, only: [put_assoc: 3, fetch_field: 2]
  alias Ecto.Multi
  alias Wizard.Repo

  alias Wizard.Sharepoint.{Authorization, Drive, Item, Service, Site}
  alias Wizard.User
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
        insert_user_and_services(user_info, services_info, authorizations_info)
      error ->
        error
    end
  end

  @spec insert_user_and_services(map, [map], [map]) :: transaction_result
  def insert_user_and_services(user_info, services_info, authorizations_info) do
    new_user_and_services(user_info, services_info, authorizations_info)
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

  @spec insert_site(map, [service: Service.t]) :: {:ok, Site.t} | {:error, Ecto.Changeset.t}
  def insert_site(attrs, [service: service]) do
    Site.changeset(%Site{}, attrs)
    |> put_assoc(:service, service)
    |> Repo.insert()
  end

  @spec insert_drive(map, [site: Site.t]) :: {:ok, Drive.t} | {:error, Ecto.Changeset.t}
  def insert_drive(attrs, [site: site]) do
    Drive.changeset(%Drive{}, attrs)
    |> put_assoc(:site, site)
    |> Repo.insert()
  end

  @spec update_drive(Drive.t, [delta_link: String.t]) :: {:ok, Drive.t} | {:error, Ecto.Changeset.t}
  def update_drive(drive, [delta_link: delta_link]) do
    drive
    |> Drive.update_delta_link_changeset(delta_link)
    |> Repo.update()
  end

  @user_conflict_options [on_conflict: :replace_all,
                          conflict_target: :email]

  defp insert_user(multi, user_info) do
    changeset = User.changeset(%User{}, user_info)

    Multi.insert(multi, :user, changeset, @user_conflict_options)
  end

  @service_conflict_options [on_conflict: :replace_all,
                             conflict_target: :resource_id]

  @spec insert_services([map]) :: {:ok, [Service.t]} | {:error, any}
  defp insert_services(infos) do
    case Multi.new |> insert_services(infos) |> Repo.transaction() do
      {:ok, changes} ->
        services = for {{:service, _}, service} <- changes, do: service
        {:ok, services}
      error ->
        error
    end
  end

  @spec insert_services(Multi.t, [map]) :: Multi.t
  defp insert_services(multi, [info | infos]) do
    changeset = Service.changeset(%Service{}, info)
    {_, resource_id} = fetch_field(changeset, :resource_id)
    name = {:service, resource_id}

    multi
    |> Multi.insert(name, changeset, @service_conflict_options)
    |> insert_services(infos)
  end

  defp insert_services(multi, []), do: multi

  @spec insert_authorizations(%{services: [Service.t], user: User.t}, [map]) :: {:ok, [Authorization.t]} | {:error, any}
  defp insert_authorizations(%{services: services, user: user}, infos) do
    case Multi.new |> insert_authorizations(user, services, infos) |> Repo.transaction() do
      {:ok, changes} ->
        auths = for {{:authorization, _}, authorization} <- changes, do: authorization
        {:ok, auths}
      error ->
        error
    end
  end

  @authorization_conflict_options [on_conflict: :replace_all,
                                   conflict_target: [:user_id, :service_id]]

  @spec insert_authorizations(Multi.t, User.t, [Service.t], [map]) :: Multi.t
  defp insert_authorizations(multi, user, services, [info | infos]) do
    case Enum.find(services, &(&1.resource_id == info[:resource_id])) do
      nil ->
        Multi.error(multi,
                    {:authorization, SecureRandom.hex()},
                    :missing_service_for_authorization_resource_id)
      service ->
        name = {:authorization, service.resource_id}

        changeset = Authorization.changeset(%Authorization{}, info)
        |> put_assoc(:user, user)
        |> put_assoc(:service, service)

        multi
        |> Multi.insert(name, changeset, @authorization_conflict_options)
        |> insert_authorizations(user, services, infos)
    end
  end

  defp insert_authorizations(multi, _, _, []), do: multi

  @spec new_user_and_services(map, [map], [map]) :: Multi.t
  defp new_user_and_services(user_info, services_info, authorizations_info) do
    Multi.new
    |> insert_user(user_info)
    |> Multi.run(:services, fn _ -> insert_services(services_info) end)
    |> Multi.run(:authorizations, &(insert_authorizations(&1, authorizations_info)))
  end

  @spec item_changeset(map, [drive: Drive.t, parent: Item.t | nil]) :: Ecto.Changeset.t
  defp item_changeset(attrs, [drive: drive, parent: nil]) do
    Item.changeset(%Item{}, attrs)
    |> put_assoc(:drive, drive)
  end

  defp item_changeset(attrs, [drive: drive, parent: parent]) do
    Item.changeset(%Item{}, attrs)
    |> put_assoc(:drive, drive)
    |> put_assoc(:parent, parent)
  end

  @spec insert_remote_item(Multi.t, map, [drive: Drive.t, parents: parents]) :: Multi.t
  def insert_remote_item(multi, info, [drive: drive, parents: parents]) do
    attrs = Item.parse_remote(info)

    if is_nil(attrs.parent_remote_id) do
      insert_item(multi, attrs, drive: drive, parent: nil)
    else
      case Map.fetch(parents, attrs.parent_remote_id) do
        {:ok, parent} ->
          insert_item(multi, attrs, drive: drive, parent: parent)
        :error ->
          Multi.run(multi, {:item, :insert, attrs.remote_id}, fn m ->
            parent = Map.get(m, {:item, :insert, attrs.parent_remote_id})
            if is_nil(parent) do
              Logger.error("couldn't find a parent for #{inspect(attrs)}")
              {:error, :missing_parent_record}
            else
              insert_item(attrs, drive: drive, parent: parent)
            end
          end)
      end
    end
  end

  @item_conflict_options [on_conflict: :replace_all,
                          conflict_target: [:remote_id, :drive_id]]

  @spec insert_item(map, [drive: Drive.t, parent: Item.t]) :: {:ok, Item.t} | {:error, Ecto.Changeset.t}
  def insert_item(attrs, [drive: drive, parent: parent]) do
    attrs
    |> item_changeset(drive: drive, parent: parent)
    |> Repo.insert(@item_conflict_options)
  end

  @spec insert_item(Multi.t, map, [drive: Drive.t, parent: Item.t]) :: Multi.t
  def insert_item(multi, attrs, [drive: drive, parent: parent]) do
    changeset = attrs
                |> item_changeset(drive: drive, parent: parent)

    case fetch_field(changeset, :remote_id) do
      :error ->
        multi
        |> Multi.error({:item, SecureRandom.hex()}, :missing_item_remote_id)
      {_, remote_id} ->
        multi
        |> Multi.insert({:item, :insert, remote_id}, changeset, @item_conflict_options)
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

  @spec insert_or_delete_remote_items([map], [drive: Drive.t]) :: transaction_result
  def insert_or_delete_remote_items(infos, [drive: drive]) do
    deletes = for info <- infos, Map.has_key?(info, "deleted"), do: info
    inserts = infos -- deletes
    parents = discover_parents(inserts, drive: drive)

    Multi.new
    |> delete_remote_items(deletes, drive: drive)
    |> insert_remote_items(inserts, drive: drive, parents: parents)
    |> Repo.transaction()
  end

  @spec delete_remote_items(Multi.t, [map], [drive: Drive.t]) :: Multi.t
  def delete_remote_items(multi, [], _), do: multi

  def delete_remote_items(multi, infos, [drive: %{id: drive_id}]) do
    remote_ids = for info <- infos, Map.has_key?(info, "id"), do: info["id"]
    query = from i in Item, where: i.remote_id in ^remote_ids, where: i.drive_id == ^drive_id
    attrs = [deleted_at: DateTime.utc_now()]

    multi
    |> Multi.update_all(:deletes, query, attrs)
  end

  @spec insert_remote_items(Multi.t, [map], [drive: Drive.t, parents: parents]) :: Multi.t
  def insert_remote_items(multi, [info | infos], [drive: drive, parents: parents]) do
    multi
    |> insert_remote_item(info, drive: drive, parents: parents)
    |> insert_remote_items(infos, drive: drive, parents: parents) # NOTE: recurse
  end

  def insert_remote_items(multi, [], [drive: _drive, parents: _parents]), do: multi # NOTE: done
end
