defmodule Wizard.Factory do
  use ExMachina.Ecto, repo: Wizard.Repo

  def user_factory do
    %Wizard.User{
      email: sequence(:email, &"email-#{&1}@example.com"),
      name: "Test User"
    }
  end

  def sharepoint_service_factory do
    %Wizard.Sharepoint.Service{
      resource_id: sequence(:resource_id, &"https://sharepoint-#{&1}.example.com/"),
      endpoint_uri: "https://sharepoint.example.com/_api",
      title: "Example Sharepoint"
    }
  end

  def sharepoint_site_factory do
    %Wizard.Sharepoint.Site{
      service: build(:sharepoint_service),
      remote_id: sequence(:site_remote_id, &"sharepoint.example.com,#{&1}"),
      url: "https://sharepoint.example.com/teams/example",
      hostname: "sharepoint.example.com",
      title: "Example Sharepoint Site",
      description: "Stop, collaborate, and listen"
    }
  end

  def sharepoint_drive_factory do
    %Wizard.Sharepoint.Drive{
      site: build(:sharepoint_site),
      remote_id: sequence(:drive_remote_id, &"b!Q-#{&1}"),
      name: "Documents",
      type: "documentLibrary",
      url: "https://sharepoint.example.com/teams/example/Shared%20Documents",
      delta_link: nil
    }
  end

  def sharepoint_root_item_factory do
    %Wizard.Sharepoint.Item{
      parent: nil,
      drive: build(:sharepoint_drive),
      remote_id: sequence(:item_remote_id, &"01TV#{&1}"),
      name: "root",
      type: "folder",
      last_modified_at: DateTime.utc_now(),
      size: 11236468176,
      url: "https://sharepoint.example.com/teams/example/Shared%20Documents"
    }
  end

  def sharepoint_item_factory do
    %Wizard.Sharepoint.Item{
      parent: build(:sharepoint_root_item),
      drive: build(:sharepoint_drive),
      remote_id: sequence(:item_remote_id, &"01TV#{&1}"),
      name: sequence(:item_name, &"file-#{&1}.txt"),
      type: "file",
      last_modified_at: DateTime.utc_now(),
      size: 11236468,
      url: "https://sharepoint.example.com/teams/example/Shared%20Documents/Somewhere"
    }
  end

  def sharepoint_authorization_factory do
    %Wizard.Sharepoint.Authorization{
      user: build(:user),
      service: build(:sharepoint_service),
      access_token: "abc",
      refresh_token: "xyz"
    }
  end

  def subscriber_subscription_factory do
    %Wizard.Subscriber.Subscription{
      user: build(:user),
      drive: build(:sharepoint_drive)
    }
  end
end
