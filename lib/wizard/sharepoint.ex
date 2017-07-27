defmodule Wizard.Sharepoint do
  require Logger

  import Ecto.Query, warn: false
  import Ecto.Changeset, only: [put_assoc: 3, fetch_field: 2]
  alias Ecto.Multi
  alias Wizard.Repo

  alias Wizard.Sharepoint.{Api, Authorization, Drive, Service, Site}
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

  def reauthorize(%Service{} = service) do
    service = Repo.preload(service, :authorization)

    case Api.Authentication.reauthorize_sharepoint_service(service) do
      {:ok, attrs} ->
        Authorization.refresh_changeset(service.authorization, attrs)
        |> Repo.update()
      error ->
        error
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

  defp insert_user(multi, user_info) do
    changeset = User.changeset(%User{}, user_info)

    options = [on_conflict: :replace_all,
               conflict_target: :email]

    Multi.insert(multi, :user, changeset, options)
  end

  @services_conflict_options [on_conflict: :replace_all,
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
    |> Multi.insert(name, changeset, @services_conflict_options)
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

  @authorizations_conflict_options [on_conflict: :replace_all,
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
        |> Multi.insert(name, changeset, @authorizations_conflict_options)
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
end
