defmodule Wizard.PreviewGenerator.Uploader.SasToken do
  @permissions %{read: "r",
                 write: "w",
                 delete: "d",
                 list: "l",
                 append: "a",
                 create: "c"}
  @service "b" # blob
  @resource_types %{container: "c",
                    blob: "b"}
  @protocol "https"
  @version "2016-05-31"
  @shift [hours: 2]
  @format "{RFC3339z}"

  defstruct service: @service,
            resource_type: "",
            permissions: "",
            starts_at: "",
            expires_at: "",
            canonicalized_resource: "",
            identifier: "",
            ip: "",
            protocol: @protocol,
            version: @version,
            cache_control: "",
            content_disposition: "",
            content_encoding: "",
            content_language: "",
            content_type: "",
            # ...
            signature: "",
            query: %{}

  @type t :: %__MODULE__{}

  @spec put(keyword) :: t
  def put([account: account, container: container, path: _path]),
    do: put(account: account, container: container)

  def put([account: account, container: container]),
    do: new(account: account, container: container, permissions: [@permissions.write,
                                                                  @permissions.create])

  @spec get(keyword) :: t
  def get([account: account, container: container, path: path]),
    do: new(account: account, container: container, path: path, permissions: [@permissions.read])

  @spec new([account: String.t,
             container: String.t,
             permissions: list(String.t)] |
            [account: String.t,
             container: String.t,
             path: String.t,
             permissions: list(String.t)] |
            [canonicalized_resource: String.t,
             permissions: list(String.t),
             resource_type: String.t]) :: t

  def new([account: account, container: container, permissions: permissions]),
    do: new(canonicalized_resource: canonicalized_resource_name(account, container),
            permissions: permissions,
            resource_type: @resource_types.container)

  def new([account: account, container: container, path: path, permissions: permissions]),
    do: new(canonicalized_resource: canonicalized_resource_name(account, container, path),
            permissions: permissions,
            resource_type: @resource_types.blob)

  def new([canonicalized_resource: canonicalized_resource, permissions: permissions, resource_type: resource_type]) do
    starts_at = Timex.now()
                |> Timex.shift(minutes: -5)
                |> Map.put(:microsecond, {0,0})
                |> Timex.format!(@format)
    expires_at = Timex.now()
                 |> Timex.shift(@shift)
                 |> Map.put(:microsecond, {0,0})
                 |> Timex.format!(@format)

    %__MODULE__{canonicalized_resource: canonicalized_resource,
                starts_at: starts_at,
                expires_at: expires_at,
                permissions: permissions,
                resource_type: resource_type}
  end

  @spec canonicalized_resource_name(String.t, String.t) :: String.t
  defp canonicalized_resource_name(account, container),
    do: "/blob/#{account}/#{container}"

  @spec canonicalized_resource_name(String.t, String.t, String.t) :: String.t
  defp canonicalized_resource_name(account, container, path),
    do: canonicalized_resource_name(account, container) <> path

  @spec string_to_sign(t) :: String.t
  defp string_to_sign(%__MODULE__{} = token) do
    [Enum.join(token.permissions),
     token.starts_at,
     token.expires_at,
     token.canonicalized_resource,
     token.identifier,
     token.ip,
     token.protocol,
     token.version,
     token.cache_control,
     token.content_disposition,
     token.content_encoding,
     token.content_language,
     token.content_type]
    |> Enum.join("\n")
  end

  @spec sign(t, binary) :: t
  def sign(%__MODULE__{} = token, decoded_access_key) do
    sig = token
          |> string_to_sign()
          |> generate_signature(decoded_access_key)

    query = token
            |> query_params(sig)

    %{token | signature: sig, query: query}
  end

  @spec generate_signature(String.t, binary) :: String.t
  defp generate_signature(string, decoded_access_key) do
    :crypto.hmac(:sha256, decoded_access_key, string)
    |> Base.encode64()
  end

  @spec query_params(t, String.t) :: String.t
  defp query_params(%__MODULE__{} = token, signature) do
    %{st: token.starts_at,
      se: token.expires_at,
      sp: Enum.join(token.permissions),
      sip: token.ip,
      spr: token.protocol,
      sv: token.version,
      "api-version": token.version,
      si: token.identifier,
      sr: token.resource_type,
      rscc: token.cache_control,
      rscd: token.content_disposition,
      rsce: token.content_encoding,
      rscl: token.content_language,
      rsct: token.content_type,
      sig: signature}
    |> Enum.filter(fn {_, v} -> v != "" end)
    |> Enum.into(%{})
    |> URI.encode_query()
  end
end
