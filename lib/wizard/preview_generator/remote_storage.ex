defmodule Wizard.PreviewGenerator.RemoteStorage do
  alias Wizard.PreviewGenerator.Uploader.SasToken

  @azure_storage_config Application.fetch_env!(:wizard, :azure_storage)
  @decoded_access_key Base.decode64!(Keyword.fetch!(@azure_storage_config, :access_key))
  @storage_account Keyword.fetch!(@azure_storage_config, :storage_account)
  @container Keyword.fetch!(@azure_storage_config, :container)
  @container_uri URI.parse(Keyword.fetch!(@azure_storage_config, :container_url))

  def decoded_access_key,
    do: @decoded_access_key

  def storage_account,
    do: @storage_account

  def container,
    do: @container

  def container_uri,
    do: @container_uri

  def get_uri(path, size) do
    token = get_token()
            |> SasToken.sign(@decoded_access_key)

    remote_path = path
                  |> sized(size)

    @container_uri
    |> URI.merge(@container_uri.path <> remote_path)
    |> Map.put(:query, token.query)
  end

  def upload_uri(path, size) do
    token = upload_token()
            |> SasToken.sign(@decoded_access_key)

    remote_path = path
                  |> sized(size)

    @container_uri
    |> URI.merge(@container_uri.path <> remote_path)
    |> Map.put(:query, token.query)
  end

  @spec upload_token() :: SasToken.t
  def upload_token,
    do: SasToken.put(account: @storage_account, container: @container)

  @spec get_token() :: SasToken.t
  def get_token,
    do: SasToken.get(account: @storage_account, container: @container)

  @spec sized(String.t, String.t) :: String.t
  defp sized(path, size) do
    ext = Path.extname(path)
    base = Path.basename(path, ext)
    dir = case Path.dirname(path) do
      "." -> ""
      other -> "#{other}/"
    end

    new_ext = "@#{size}#{ext}"

    "#{dir}#{base}#{new_ext}"
  end
end
