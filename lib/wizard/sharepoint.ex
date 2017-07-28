defmodule Wizard.Sharepoint do
  require Logger

  import Ecto.Query, warn: false
  import Ecto.Changeset, only: [put_assoc: 3, fetch_field: 2]
  alias Ecto.Multi
  alias Wizard.Repo

  alias Wizard.Sharepoint.{Api, Authorization, Drive, Item, Service, Site}
  alias Wizard.User

  def authorize_url(state),
    do: Api.Authentication.authorize_url(state)

  def authorize_sharepoints(code) do
    case Api.Authentication.authorize_sharepoints(code) do
      {:ok, user_info, services_info, authorizations_info} ->
        insert_user_and_services(user_info, services_info, authorizations_info)
      error ->
        error
    end
  end

  def insert_user_and_services(user_info, services_info, authorizations_info) do
    new_user_and_services(user_info, services_info, authorizations_info)
    |> Repo.transaction()
  end

  def reauthorize(%Service{} = service, %User{} = user) do
    case Repo.get_by(Authorization, service_id: service.id, user_id: user.id) do
      nil -> {:error, :authorization_not_found}
      auth ->
        case Api.Authentication.reauthorize_sharepoint_service(service, auth.refresh_token) do
          {:ok, attrs} ->
            Authorization.refresh_changeset(auth, attrs)
            |> Repo.update()
          error ->
            error
        end
    end
  end

  def remotely_search_sites(service, user, query) do
    case Repo.get_by(Authorization, service_id: service.id, user_id: user.id) do
      nil -> {:error, :unauthorized}
      auth ->
        Api.Sites.search(auth, service, query)
    end
  end

  def remotely_list_drives(site, user) do
    site = Repo.preload(site, :service)

    case Repo.get_by(Authorization, service_id: site.service.id, user_id: user.id) do
      nil -> {:error, :unauthorized}
      auth -> Api.Sites.drives(auth, site)
    end
  end

  def insert_site(attrs, [service: service]) do
    Site.changeset(%Site{}, attrs)
    |> put_assoc(:service, service)
    |> Repo.insert()
  end

  def insert_drive(attrs, [site: site]) do
    Drive.changeset(%Drive{}, attrs)
    |> put_assoc(:site, site)
    |> Repo.insert()
  end

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

  defp insert_services(infos) do
    case Multi.new |> insert_services(infos) |> Repo.transaction() do
      {:ok, changes} ->
        services = for {{:service, _}, service} <- changes, do: service
        {:ok, services}
      error ->
        error
    end
  end

  defp insert_services(multi, [info | infos]) do
    changeset = Service.changeset(%Service{}, info)
    {_, resource_id} = fetch_field(changeset, :resource_id)
    name = {:service, resource_id}

    multi
    |> Multi.insert(name, changeset, @service_conflict_options)
    |> insert_services(infos)
  end

  defp insert_services(multi, []), do: multi

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

  defp insert_authorizations(multi, user, services, [info | infos]) do
    case Enum.find(services, &(&1.resource_id == info[:resource_id])) do
      nil ->
        Multi.error(multi,
                    {:authorization, :missing_service},
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

  defp new_user_and_services(user_info, services_info, authorizations_info) do
    Multi.new
    |> insert_user(user_info)
    |> Multi.run(:services, fn _ -> insert_services(services_info) end)
    |> Multi.run(:authorizations, &(insert_authorizations(&1, authorizations_info)))
  end

  defp item_changeset(info, [drive: drive, parent: parent]) do
    Item.changeset(%Item{}, info)
    |> put_assoc(:drive, drive)
    |> put_assoc(:parent, parent)
  end

  @item_conflict_options [on_conflict: :replace_all,
                          conflict_target: :remote_id]

  def insert_item(%Multi{} = multi, info, [drive: drive]) do
    info = Item.parse_remote(info)

    # FIXME: N+1 problem with parent lookup
    parent = case info.parent_remote_id do
      nil -> nil
      remote_id ->
        Repo.get_by(Item, remote_id: remote_id, drive_id: drive.id)
    end

    changeset = info
                |> item_changeset(drive: drive, parent: parent)

    case fetch_field(changeset, :remote_id) do
      :error ->
        multi
        |> Multi.error({:item, :missing_remote_id}, :missing_item_remote_id)
      {_, remote_id} ->
        multi
        |> Multi.insert({:item, :insert, remote_id}, changeset, @item_conflict_options)
    end
  end

  def delete_item(%Multi{} = multi, remote_id, [drive: drive]) do
    # FIXME: N+1 problem with item lookup
    case Repo.get_by(Item, remote_id: remote_id, drive_id: drive.id) do
      nil -> multi # NOTE: nothing to delete
      item ->
        changeset = Item.delete_changeset(item)

        multi
        |> Multi.update({:item, :delete, item.id}, changeset)
    end
  end

  def insert_or_delete_remote_items(infos, [drive: drive]) do
    Multi.new
    |> insert_or_delete_remote_items(infos, drive: drive)
    |> Repo.transaction()
  end

  def insert_or_delete_remote_items(multi, [info | infos], [drive: drive]) do
    case info do
      %{"deleted" => _, "id" => remote_id} ->
        multi
        |> delete_item(remote_id, drive: drive)
        |> insert_or_delete_remote_items(infos, drive: drive)
      _ ->
        multi
        |> insert_item(info, drive: drive)
        |> insert_or_delete_remote_items(infos, drive: drive) # NOTE: recurse
    end
  end

  def insert_or_delete_remote_items(multi, [], [drive: _drive]), do: multi # NOTE: done
end
