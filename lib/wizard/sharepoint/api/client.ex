defmodule Wizard.Sharepoint.Api.Client do
  require Logger
  use Wizard.Sharepoint.Api

  @accept_header [{"Accept", "application/json;odata.metadata=full"}]
  @json_content_type_header [{"Content-Type", "application/json"}]
  @form_content_type_header [{"Content-Type", "application/x-www-form-urlencoded"}]

  @default_http_options [timeout: 60_000, recv_timeout: 60_000]

  def get(url, opts \\ []) do
    h = headers(opts)
    Logger.debug inspect({:getting, url, h})
    decode_json_response HTTPoison.get(url, h, @default_http_options)
  end

  def download(url, [to: path, access_token: access_token]) do
    h = access_token_header([access_token: access_token])
    Logger.debug inspect({:getting, url, h})

    with response = HTTPoison.get(url, h, @default_http_options),
         {:ok, location} <- decode_download_response(response),
         {:ok, _} <- download_from(location, path: path),
      do: :ok
  end

  @spec decode_download_response(Api.result) :: {:ok, String.t} | {:error, :download_failed}
  defp decode_download_response(response) do
    case decode_json_response(response) do
      {:ok, %{location: location}} ->
        {:ok, location}
      {:error, error_response} ->
        Logger.error "Download failed with response: #{inspect error_response}"
        {:error, :download_failed}
    end
  end

  defp download_from(location, [path: path]) do
    Logger.debug("Downloading from #{location} to #{path}")
    Download.from(location, path: path)
  end

  def post(url, body, opts \\ []) do
    json = Poison.encode!(body)
    opts = opts ++ [additional_headers: @json_content_type_header]
    h = headers(opts)
    Logger.debug inspect({:posting, url, h, json})
    decode_json_response HTTPoison.post(url, json, h, @default_http_options)
  end

  def post_form(url, body, opts \\ []) do
    body = URI.encode_query(body)
    opts = opts ++ [additional_headers: @form_content_type_header]
    h = headers(opts)
    Logger.debug inspect({:posting_form, url, h, body})
    decode_json_response HTTPoison.post(url, body, h, @default_http_options)
  end

  def delete(url, opts \\ []) do
    h = headers(opts)
    Logger.debug inspect({:deleting, url, h})
    decode_json_response HTTPoison.delete(url, h, @default_http_options)
  end

  @spec access_token_header(Keyword.t) :: Api.headers
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

  @spec headers(Keyword.t) :: Api.headers
  defp headers(opts) do
    @accept_header ++ access_token_header(opts) ++ additional_headers(opts)
  end

  @spec decode_json_response({:ok | :error, %HTTPoison.Response{}}) :: Api.result
  defp decode_json_response(resp) do
    case resp do
      {:ok, r} ->
        IO.puts("########################################")
        IO.puts("#{r.status_code} - #{r.request_url}")
        IO.puts("########################################")
        IO.puts(r.body)
        IO.puts("########################################")
      {:error, error} ->
        IO.puts("########################################")
        IO.puts(inspect(error))
        IO.puts("########################################")
    end

    case resp do
      {:ok, %HTTPoison.Response{status_code: 200, body: body} = response} ->
        Logger.debug inspect({:response, response})
        Poison.decode(body)
      {:ok, %HTTPoison.Response{status_code: 201, body: body} = response} ->
        Logger.debug inspect({:response, response})
        Poison.decode(body)
      {:ok, %HTTPoison.Response{status_code: 204} = response} ->
        Logger.debug inspect({:response, response})
        {:ok, nil}
      {:ok, %HTTPoison.Response{status_code: 302} = response} ->
        {_, location} = response.headers
                      |> Enum.find(fn {key, _} -> key == "Location" end)
        {:ok, %{location: location}}
      {:ok, %HTTPoison.Response{status_code: 401} = response} ->
        Logger.debug inspect({:response, response})
        IO.puts("Maybe the access_token has expired")
        {:error, :unauthorized}
      {:ok, %HTTPoison.Response{status_code: 410, body: body} = response} ->
        case Poison.decode(body) do
          {:ok, %{"error" => %{"code" => "resyncRequired"}}} ->
            {:error, :reset_delta_url}
          _ ->
            Logger.debug inspect({:response, response})
            {:error, :unsuccessful_response}
        end
      {:ok, response} ->
        Logger.debug inspect(response)
        {:error, :unsuccessful_response}
      error ->
        Logger.debug inspect(error)
        error
    end
  end
end
