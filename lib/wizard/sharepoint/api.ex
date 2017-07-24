defmodule Wizard.Sharepoint.Api do
  require Logger

  @ssl_settings [ssl: [{:versions, [:'tlsv1.2']}]]
  @accept_header [{"Accept", "application/json;odata.metadata=full"}]
  @content_type_header [{"Content-Type", "application/json"}]

  def get(url, access_token) do
    h = headers(access_token)
    Logger.debug inspect({:getting, url, h})
    decode_json_response HTTPoison.get(url, h, @ssl_settings)
  end

  def post(url, body, access_token) do
    json = Poison.encode!(body)
    h = headers(access_token, @content_type_header)
    Logger.debug inspect({:posting, url, h, json})
    decode_json_response HTTPoison.post(url, json, h, @ssl_settings)
  end

  def delete(url, access_token) do
    h = headers(access_token)
    Logger.debug inspect({:deleting, url, h})
    decode_json_response HTTPoison.delete(url, h, @ssl_settings)
  end

  def headers(access_token, additional_headers \\ []) do
    @accept_header ++ additional_headers ++ [{"Authorization", "Bearer #{access_token}"}]
  end

  def decode_json_response(resp) do
    case resp do
      {:ok,  %HTTPoison.Response{status_code: 200, body: body} = response} ->
        Logger.debug inspect({:response, response})
        Poison.decode!(body)
      {:ok,  %HTTPoison.Response{status_code: 201, body: body} = response} ->
        Logger.debug inspect({:response, response})
        Poison.decode!(body)
      {:ok,  %HTTPoison.Response{status_code: 204} = response} ->
        Logger.debug inspect({:response, response})
        {:ok, nil}
      {:ok,  %HTTPoison.Response{status_code: 401} = response} ->
        Logger.debug inspect({:response, response})
        IO.puts("Maybe the access_token has expired")
        {:error, :unauthorized}
      {:ok, response} ->
        Logger.debug inspect(response)
        {:error, :unsuccessful_response}
      {:error, _} = error ->
        Logger.debug inspect({:error, error})
        error
    end
  end
end
