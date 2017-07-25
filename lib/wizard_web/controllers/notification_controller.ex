defmodule WizardWeb.NotificationController do
  use WizardWeb, :controller

  def callback(conn, %{"validationtoken" => token}) do
    conn |> text(token)
  end

  def callback(conn, %{"value" => subscriptions}) do
    IO.inspect({:subscriptions, subscriptions})
    conn |> text("thanks")
  end
end
