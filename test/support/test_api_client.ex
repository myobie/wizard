defmodule Wizard.TestApiClient do
  use Wizard.ApiClient

  def get(url, opts \\ []), do: {:ok, nil}
  def post(url, body, opts \\ []), do: {:ok, nil}
  def post_form(url, body, opts \\ []), do: {:ok, nil}
  def delete(url, opts \\ []), do: {:ok, nil}
end
