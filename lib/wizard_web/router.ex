defmodule WizardWeb.Router do
  use WizardWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :aad_auth do
    plug :fetch_session
  end

  scope "/", WizardWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index

    resources "/feeds", FeedController do
      resources "/previews", PreviewController
    end

    get "/signin", AuthenticationController, :signin
  end

  scope "/notifications", WizardWeb do
    pipe_through :api

    post "/callback", NotificationController, :callback
  end

  scope "/authentication", WizardWeb do
    pipe_through :aad_auth

    post "/callback", AuthenticationController, :callback
    get "/callback", AuthenticationController, :callback
  end
end
