defmodule Wizard.Sharepoint.Api do
  require Logger
  use Wizard.ApiClient

  @type response :: HTTPoison.Response.t

  @accept_header [{"Accept", "application/json;odata.metadata=full"}]
  @json_content_type_header [{"Content-Type", "application/json"}]
  @form_content_type_header [{"Content-Type", "application/x-www-form-urlencoded"}]

  def get(url, opts \\ []) do
    h = headers(opts)
    Logger.debug inspect({:getting, url, h})
    decode_json_response HTTPoison.get(url, h, [])
  end

  def post(url, body, opts \\ []) do
    json = Poison.encode!(body)
    opts = opts ++ [additional_headers: @json_content_type_header]
    h = headers(opts)
    Logger.debug inspect({:posting, url, h, json})
    decode_json_response HTTPoison.post(url, json, h, [])
  end

  def post_form(url, body, opts \\ []) do
    body = URI.encode_query(body)
    opts = opts ++ [additional_headers: @form_content_type_header]
    h = headers(opts)
    Logger.debug inspect({:posting_form, url, h, body})
    decode_json_response HTTPoison.post(url, body, h, [])
  end

  def delete(url, opts \\ []) do
    h = headers(opts)
    Logger.debug inspect({:deleting, url, h})
    decode_json_response HTTPoison.delete(url, h, [])
  end

  @spec access_token_header(Keyword.t) :: ApiClient.headers
  defp access_token_header(opts) do
    case Keyword.get(opts, :access_token) do
      nil -> []
      token -> [{"Authorization", "Bearer #{token}"}]
    end
  end

  defp additional_headers(opts) do
    case Keyword.get(opts, :additional_headers) do
      nil -> []
      headers -> headers
    end
  end

  @spec headers(Keyword.t) :: ApiClient.headers
  defp headers(opts) do
    @accept_header ++ access_token_header(opts) ++ additional_headers(opts)
  end

  @spec decode_json_response({:ok | :error, response}) :: ApiClient.result
  defp decode_json_response(resp) do
    {_, r} = resp
    IO.puts("########################################")
    IO.puts("#{r.status_code} - #{r.request_url}")
    IO.puts("########################################")
    IO.puts(r.body)
    IO.puts("########################################")

    case resp do
      {:ok, %HTTPoison.Response{status_code: 200, body: body} = response} ->
        Logger.debug inspect({:response, response})
        Poison.decode(body)
      {:ok, %HTTPoison.Response{status_code: 201, body: body} = response} ->
        Logger.debug inspect({:response, response})
        Poison.decode(body)
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
      error ->
        Logger.debug inspect(error)
        error
    end
  end
end
