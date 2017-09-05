defmodule Wizard.Sharepoint.Api do
  alias Wizard.Sharepoint.Api.MissingApiClient

  @type headers :: [{String.t, String.t}]
  @type json :: Poison.Parser.t
  @type result :: {:ok, json} | {:error, any}
  @type opts :: [access_token: String.t] | Keyword.t

  @callback get(String.t, opts) :: result
  @callback download(String.t, opts) :: :ok | {:error, atom}
  @callback post(String.t, json, opts) :: result
  @callback post_form(String.t, map, opts) :: result
  @callback delete(String.t, opts) :: result

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)
      alias unquote(__MODULE__)
    end
  end

  @spec client() :: __MODULE__
  def client do
    Application.get_env(:wizard, :sharepoint_api_client, MissingApiClient)
  end
end
