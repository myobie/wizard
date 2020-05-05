defmodule Wizard.Sharepoint.Api.MissingApiClient do
  @result {:error, :missing_api_client}

  def get(_, _), do: @result
  def post(_, _, _), do: @result
  def post_form(_, _, _), do: @result
  def delete(_, _), do: @result
end
