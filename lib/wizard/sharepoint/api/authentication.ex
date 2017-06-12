defmodule Wizard.Sharepoint.Api.Authentication do
  @client_id Application.fetch_env!(:wizard, :aad_client_id)
  @client_secret Application.fetch_env!(:wizard, :aad_client_secret)
  @redirect_url Application.fetch_env!(:wizard, :aad_redirect_url)
  @base_url "https://login.microsoftonline.com/common/oauth2"
  @authorize_uri URI.parse("#{@base_url}/authorize")
  @discovery_url "https://api.office.com/discovery/"
  @services_url "https://api.office.com/discovery/v2.0/me/services"
  @token_url "#{@base_url}/token"
  @response_type "code"
  @ssl_settings [ssl: [{:versions, [:'tlsv1.2']}]]

  alias Wizard.Sharepoint.Api
  import Api, only: [decode_json_response: 1]

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

  def authorize_first_sharepoint(code) do
    with {:ok, d_access_token, d_refresh_token, id_token} <- get_discovery_token(code),
         {:ok, resource_id, url} <- discover_first_sharepoint_url(d_access_token),
         {:ok, access_token, refresh_token} <- authorize_sharepoint_resource(resource_id, refresh_token: d_refresh_token),
         {:ok, name, email} <- extract_user_information(id_token) do
      {:ok, %{
        "resource_id": resource_id,
        "url": url,
        "name": name,
        "email": email,
        "refresh_token": refresh_token,
        "access_token": access_token
      }}
    end
  end

  def reauthorize_sharepoint(resource_id, refresh_token),
    do: authorize_sharepoint_resource(resource_id, refresh_token: refresh_token)

  defp extract_user_information(id_token) do
    case JOSE.JWT.peek_payload(id_token) do
      %JOSE.JWT{fields: %{"name" => name, "upn" => email}} ->
        {:ok, name, email}
      _ ->
        {:error, :jwt_decode_failed}
    end
  end

  defp authorize_sharepoint_resource(resource_id, [refresh_token: refresh_token]) do
    resp = get_token(refresh_token: refresh_token, resource: resource_id)
    case resp do
      %{"access_token" => access_token, "refresh_token" => refresh_token} ->
        {:ok, access_token, refresh_token}
      _ ->
        {:error, :get_token_failed}
    end
  end

  defp discover_first_sharepoint_url(access_token) do
    with {:ok, services} <- discover_services(access_token),
         {:ok, service} <- discover_first_sharepoint_service(services) do
      {:ok, service["serviceResourceId"], service["serviceEndpointUri"]}
    end
  end

  defp get_discovery_token(code) do
    resp = get_token(code: code, resource: @discovery_url)
    case resp do
      %{"access_token" => access_token, "refresh_token" => refresh_token, "id_token" => id_token} ->
        {:ok, access_token, refresh_token, id_token}
      _ ->
        {:error, :get_token_failed}
    end
  end

  defp discover_services(token) do
    resp = Api.get(@services_url, token)
    case resp do
      %{"value" => services} ->
        {:ok, services}
      _ ->
        {:error, :get_services_failed}
    end
  end

  defp discover_first_sharepoint_service(services) do
    case Enum.find(services, fn(o) -> o["capability"] == "RootSite" end) do
      nil -> {:error, :discover_sharepoint_service_failed}
      service -> {:ok, service}
    end
  end

  defp get_token([refresh_token: refresh_token, resource: resource]) do
    post_form @token_url, %{
      client_id: @client_id,
      client_secret: @client_secret,
      redirect_uri: @redirect_url,
      refresh_token: refresh_token,
      resource: resource,
      grant_type: :refresh_token
    }
  end

  defp get_token([code: code, resource: resource]) do
    post_form @token_url, %{
      client_id: @client_id,
      client_secret: @client_secret,
      redirect_uri: @redirect_url,
      code: code,
      resource: resource,
      grant_type: :authorization_code
    }
  end

  defp post_form(url, body) do
    body = URI.encode_query(body)
    decode_json_response HTTPoison.post(url, body, [{"Accept", "application/json"}, {"Content-Type", "application/x-www-form-urlencoded"}], @ssl_settings)
  end
end
