defmodule Wizard.Sharepoint do
  require Logger

  import Ecto.Query, warn: false
  import Ecto.Changeset, only: [put_assoc: 3]
  alias Ecto.Multi
  alias Wizard.Repo

  alias Wizard.Sharepoint.{Authorization, Drive, Site, User}
  alias Wizard.Sharepoint.Api

  def authorize_url(state),
    do: Api.Authentication.authorize_url(state)

  def authorize_first_sharepoint(code),
    do: Api.Authentication.authorize_first_sharepoint(code)

  def create_user_and_authorization(info) do
    new_user_and_authorization(info)
    |> Repo.transaction()
  end

  def reauthorize(authorization) do
    %{resource_id: resource_id, refresh_token: old_refresh_token} = authorization
    case Api.Authentication.reauthorize_sharepoint(resource_id, old_refresh_token) do
      {:ok, access_token, refresh_token} ->
        Authorization.refresh_changeset(authorization, %{access_token: access_token, refresh_token: refresh_token})
        |> Repo.update()
      error ->
        error
    end
  end

  def search_sites(query, authorization),
    do: Api.Sites.search(query, authorization)

  def list_drives_for_site(site_id, authorization),
    do: Api.Sites.drives(site_id, authorization)

  def create_site(attrs, [authorization: authorization]) do
    Site.changeset(%Site{}, attrs)
    |> put_assoc(:authorization, authorization)
    |> Repo.insert()
  end

  def create_drive(attrs, [site: site]) do
    Drive.changeset(%Drive{}, attrs)
    |> put_assoc(:site, site)
    |> Repo.insert()
  end

  defp new_user_and_authorization(info) do
    user = User.changeset(%User{}, info)

    Multi.new
    |> Multi.run(:user, fn _ ->
      options = [
        on_conflict: [set: User.on_conflict_options(user)],
        conflict_target: :email
      ]
      Repo.insert(user, options)
    end)
    |> Multi.run(:authorization, fn %{user: user} ->
      authorization = Authorization.changeset(%Authorization{}, info)
                      |> put_assoc(:user, user)
      options = [
        on_conflict: [set: Authorization.on_conflict_options(authorization)],
        conflict_target: [:resource_id, :user_id]
      ]
      Repo.insert(authorization, options)
    end)
  end
end
