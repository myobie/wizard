defmodule WizardWeb.GuardianNoauthPipeline do
  use Guardian.Plug.Pipeline, otp_app: :wizard,
                              module: WizardWeb.Guardian,
                              error_handler: WizardWeb.AuthErrorHandler

  plug Guardian.Plug.VerifySession
  plug Guardian.Plug.LoadResource, allow_blank: true
end
