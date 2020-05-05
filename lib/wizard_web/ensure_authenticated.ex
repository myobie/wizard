defmodule WizardWeb.EnsureAuthenticated do
  use Guardian.Plug.Pipeline, otp_app: :wizard,
                              module: WizardWeb.Guardian,
                              error_handler: WizardWeb.AuthErrorHandler

  plug Guardian.Plug.VerifySession
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
