defmodule WizardWeb.LayoutView do
  use WizardWeb, :view

  def authenticated?(conn),
    do: WizardWeb.Guardian.Plug.authenticated?(conn, [])
end
