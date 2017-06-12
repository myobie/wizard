defmodule Wizard.Sharepoint.Api do
  @ssl_settings [ssl: [{:versions, [:'tlsv1.2']}]]
  @accept_header [{"Accept", "application/json;odata.metadata=full"}]
  @content_type_header [{"Content-Type", "application/json"}]

  def get(url, access_token) do
    h = headers(access_token)
    IO.inspect {:getting, url, h}
    decode_json_response HTTPoison.get(url, h, @ssl_settings)
  end

  def post(url, body, access_token) do
    json = Poison.encode!(body)
    h = headers(access_token, @content_type_header)
    IO.inspect {:posting, url, h, json}
    decode_json_response HTTPoison.post(url, json, h, @ssl_settings)
  end

  def delete(url, access_token) do
    h = headers(access_token)
    IO.inspect {:deleting, url, h}
    decode_json_response HTTPoison.delete(url, h, @ssl_settings)
  end

  def headers(access_token, additional_headers \\ []) do
    @accept_header ++ additional_headers ++ [{"Authorization", "Bearer #{access_token}"}]
  end

  def decode_json_response(resp) do
    case resp do
      {:ok,  %HTTPoison.Response{status_code: 200, body: body} = response} ->
        IO.inspect({:response, response})
        Poison.decode!(body)
      {:ok,  %HTTPoison.Response{status_code: 201, body: body} = response} ->
        IO.inspect({:response, response})
        Poison.decode!(body)
      {:ok,  %HTTPoison.Response{status_code: 204} = response} ->
        IO.inspect({:response, response})
        {:ok, nil}
      {:ok,  %HTTPoison.Response{status_code: 401} = response} ->
        IO.inspect({:response, response})
        IO.puts("Maybe the access_token has expired")
        {:error, :unauthorized}
      {:ok, response} ->
        IO.inspect(response)
        {:error, :unsuccessful_response}
      {:error, _} = error ->
        IO.inspect({:error, error})
        error
    end
  end
end
