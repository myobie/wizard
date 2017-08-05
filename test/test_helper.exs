{:ok, _} = Wizard.TestApiClient.start_link()

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Wizard.Repo, :manual)

