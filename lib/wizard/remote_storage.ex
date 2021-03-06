defmodule Wizard.RemoteStorage do
  alias Wizard.RemoteStorage.{Getter, Putter, SasToken}

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

  def put_exported_files(files),
    do: Putter.put_exported_files(files)

  def get_preview(preview), do: Getter.get_preview(preview)
  def get_preview(preview, size),
    do: Getter.get_preview(preview, size)

  def get_preview_raw_data(preview), do: Getter.get_preview_raw_data(preview)
  def get_preview_raw_data(preview, size),
    do: Getter.get_preview_raw_data(preview, size)

  def get_uri(path, size) do
    remote_path = path
                  |> sized(size)

    token = get_token(remote_path)
            |> SasToken.sign(@decoded_access_key)

    @container_uri
    |> URI.merge(@container_uri.path <> remote_path)
    |> Map.put(:query, token.query)
  end

  def put_uri(path, size) do
    token = put_token()
            |> SasToken.sign(@decoded_access_key)

    remote_path = path
                  |> sized(size)

    @container_uri
    |> URI.merge(@container_uri.path <> remote_path)
    |> Map.put(:query, token.query)
  end

  @spec put_token() :: SasToken.t
  def put_token,
    do: SasToken.put(account: @storage_account, container: @container)

  @spec get_token(String.t) :: SasToken.t
  def get_token(path),
    do: SasToken.get(account: @storage_account, container: @container, path: path)

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
