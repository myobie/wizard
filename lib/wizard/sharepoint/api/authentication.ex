defmodule Wizard.Sharepoint.Api.Authentication do
  require Logger
  alias Wizard.ApiClient

  @client_id Application.fetch_env!(:wizard, :aad_client_id)
  @client_secret Application.fetch_env!(:wizard, :aad_client_secret)
  @redirect_url Application.fetch_env!(:wizard, :aad_redirect_url)
  @base_url "https://login.microsoftonline.com/common/oauth2"
  @authorize_uri URI.parse("#{@base_url}/authorize")
  @discovery_url "https://api.office.com/discovery/"
  @services_url "https://api.office.com/discovery/v2.0/me/services"
  @token_url "#{@base_url}/token"
  @response_type "code"

  alias Wizard.Sharepoint.{Api, Service}

  @spec authorize_url(String.t) :: String.t
  def authorize_url(state) do
    params = %{
      client_id: @client_id,
      redirect_uri: @redirect_url,
      response_type: @response_type,
      state: state
    }
    query = URI.encode_query(params)
    to_string %{@authorize_uri | query: query}
  end

  @spec authorize_sharepoints(String.t) :: {:ok, map, list(map), list(map)} | {:error, any}
  def authorize_sharepoints(code) do
    with {:ok, d_access_token, d_refresh_token, id_token} <- get_discovery_token(code),
         {:ok, services} <- discover_sharepoint_services(d_access_token),
         {:ok, authorizations} <- authorize_sharepoint_services(services, d_refresh_token),
         {:ok, user} <- extract_user_information(id_token) do
      {:ok, user, services, authorizations}
    end
  end

  @spec extract_user_information(String.t) :: {:ok, map} | {:error, atom}
  defp extract_user_information(id_token) do
    case JOSE.JWT.peek_payload(id_token) do
      %JOSE.JWT{fields: %{"name" => name, "upn" => email}} ->
        {:ok, %{name: name, email: email}}
      _ ->
        {:error, :jwt_decode_failed}
    end
  end

  def reauthorize_sharepoint_service(service, refresh_token) do
    authorize_sharepoint_service(service, refresh_token)
  end

  @spec authorize_sharepoint_services([map], String.t) :: {:ok, [map]} | {:error, any}
  defp authorize_sharepoint_services(services, refresh_token) do
    authorize_sharepoint_services([], services, refresh_token)
  end

  @spec authorize_sharepoint_services([map], [map], String.t) :: {:ok, [map]} | {:error, any}
  defp authorize_sharepoint_services(authorizations, [service | services], refresh_token) do
    case authorize_sharepoint_service(service, refresh_token) do
      {:ok, auth} ->
        authorize_sharepoint_services([auth | authorizations], services, refresh_token)
      error ->
        error
    end
  end

  defp authorize_sharepoint_services(authorizations, [], _), do: {:ok, authorizations}

  @spec authorize_sharepoint_service(Service.t, String.t) :: {:ok, map} | {:error, atom}
  defp authorize_sharepoint_service(service, refresh_token) do
    case get_token(refresh_token: refresh_token, resource: service.resource_id) do
      {:ok, %{"access_token" => access_token, "refresh_token" => refresh_token}} ->
        {:ok, %{access_token: access_token, refresh_token: refresh_token, resource_id: service.resource_id}}
      _ ->
        {:error, :get_token_failed}
    end
  end

  @spec get_discovery_token(String.t) :: {:ok, String.t, String.t, String.t} | {:error, atom}
  defp get_discovery_token(code) do
    case get_token(code: code, resource: @discovery_url) do
      {:ok, %{"access_token" => access_token, "refresh_token" => refresh_token, "id_token" => id_token}} ->
        {:ok, access_token, refresh_token, id_token}
      _ ->
        {:error, :get_token_failed}
    end
  end

  @spec is_sharepoint_service?(map) :: boolean
  def is_sharepoint_service?(info), do: info["capability"] == "RootSite"

  @spec discover_sharepoint_services(String.t) :: {:ok, [map]} | {:error, atom}
  defp discover_sharepoint_services(token) do
    case Api.get(@services_url, access_token: token) do
      {:ok, %{"value" => services}} ->
        services = for info <- services, is_sharepoint_service?(info) do
          %{resource_id: info["serviceResourceId"],
            endpoint_uri: info["serviceEndpointUri"],
            title: "#{info["serviceName"]} – #{info["providerName"]}"}
        end
        Logger.debug inspect({:sharepoint_services, services})
        {:ok, services}
      _ ->
        {:error, :discover_sharepoint_services_failed}
    end
  end

  @spec get_token([code: String.t, resource: String.t] | [refresh_token: String.t, resource: String.t]) :: ApiClient.result
  defp get_token([refresh_token: refresh_token, resource: resource]) do
    Api.post_form @token_url, %{
      client_id: @client_id,
      client_secret: @client_secret,
      redirect_uri: @redirect_url,
      refresh_token: refresh_token,
      resource: resource,
      grant_type: :refresh_token
    }
  end

  defp get_token([code: code, resource: resource]) do
    Api.post_form @token_url, %{
      client_id: @client_id,
      client_secret: @client_secret,
      redirect_uri: @redirect_url,
      code: code,
      resource: resource,
      grant_type: :authorization_code
    }
  end
end
