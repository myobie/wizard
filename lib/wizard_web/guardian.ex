defmodule WizardWeb.Guardian do
  use Guardian, otp_app: :wizard

  alias Wizard.{Repo, User}

  def subject_for_token(%User{} = resource, _claims) do
    {:ok, "User:#{resource.id}"}
  end

  def subject_for_token(_resource, _claims),
    do: {:error, :unknown_resource_type}

  def resource_from_claims(%{"sub" => sub}) do
    case sub do
      "User:" <> id ->
        case find(id) do
          nil -> {:error, :not_found}
          user -> {:ok, user}
        end
      _ -> {:error, :subject_not_a_valid_resource}
    end
  end

  defp find(string_id) do
    string_id
    |> String.to_integer()
    |> get()
  end

  defp get(id), do: Repo.get(User, id)
end
