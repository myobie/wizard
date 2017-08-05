defmodule Wizard.ApiClientTest do
  use Wizard.DataCase
  alias Wizard.TestApiClient, as: Client

  @api_client Application.get_env(:wizard, :sharepoint_api_client)

  test "unmocked request returns an error" do
    assert match?({:error, :no_matcher_for_request}, @api_client.get("/"))
  end

  test "can mock requests by method and url" do
    Client.match(:GET, ~r{\A/\z}, {:ok, %{"value" => 8}})
    {:ok, resp} = @api_client.get("/")
    assert resp["value"] == 8
  end
end
