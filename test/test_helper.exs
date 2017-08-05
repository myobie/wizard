{:ok, _} = Wizard.TestApiClient.start_link()
{:ok, _} = Application.ensure_all_started(:ex_machina)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Wizard.Repo, :manual)

