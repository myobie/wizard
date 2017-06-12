defmodule Wizard.SharepointTest do
  use Wizard.DataCase

  alias Wizard.Sharepoint

  describe "users" do
    alias Wizard.Sharepoint.User

    @valid_attrs %{email: "some email", name: "some name"}
    @update_attrs %{email: "some updated email", name: "some updated name"}
    @invalid_attrs %{email: nil, name: nil}

    def user_fixture(attrs \\ %{}) do
      {:ok, user} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Sharepoint.create_user()

      user
    end

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert Sharepoint.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Sharepoint.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = Sharepoint.create_user(@valid_attrs)
      assert user.email == "some email"
      assert user.name == "some name"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sharepoint.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      assert {:ok, user} = Sharepoint.update_user(user, @update_attrs)
      assert %User{} = user
      assert user.email == "some updated email"
      assert user.name == "some updated name"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Sharepoint.update_user(user, @invalid_attrs)
      assert user == Sharepoint.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Sharepoint.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Sharepoint.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Sharepoint.change_user(user)
    end
  end

  describe "authorizations" do
    alias Wizard.Sharepoint.Authorization

    @valid_attrs %{access_token: "some access_token", refresh_token: "some refresh_token", resource_id: "some resource_id", url: "some url"}
    @update_attrs %{access_token: "some updated access_token", refresh_token: "some updated refresh_token", resource_id: "some updated resource_id", url: "some updated url"}
    @invalid_attrs %{access_token: nil, refresh_token: nil, resource_id: nil, url: nil}

    def authorization_fixture(attrs \\ %{}) do
      {:ok, authorization} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Sharepoint.create_authorization()

      authorization
    end

    test "list_authorizations/0 returns all authorizations" do
      authorization = authorization_fixture()
      assert Sharepoint.list_authorizations() == [authorization]
    end

    test "get_authorization!/1 returns the authorization with given id" do
      authorization = authorization_fixture()
      assert Sharepoint.get_authorization!(authorization.id) == authorization
    end

    test "create_authorization/1 with valid data creates a authorization" do
      assert {:ok, %Authorization{} = authorization} = Sharepoint.create_authorization(@valid_attrs)
      assert authorization.access_token == "some access_token"
      assert authorization.refresh_token == "some refresh_token"
      assert authorization.resource_id == "some resource_id"
      assert authorization.url == "some url"
    end

    test "create_authorization/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sharepoint.create_authorization(@invalid_attrs)
    end

    test "update_authorization/2 with valid data updates the authorization" do
      authorization = authorization_fixture()
      assert {:ok, authorization} = Sharepoint.update_authorization(authorization, @update_attrs)
      assert %Authorization{} = authorization
      assert authorization.access_token == "some updated access_token"
      assert authorization.refresh_token == "some updated refresh_token"
      assert authorization.resource_id == "some updated resource_id"
      assert authorization.url == "some updated url"
    end

    test "update_authorization/2 with invalid data returns error changeset" do
      authorization = authorization_fixture()
      assert {:error, %Ecto.Changeset{}} = Sharepoint.update_authorization(authorization, @invalid_attrs)
      assert authorization == Sharepoint.get_authorization!(authorization.id)
    end

    test "delete_authorization/1 deletes the authorization" do
      authorization = authorization_fixture()
      assert {:ok, %Authorization{}} = Sharepoint.delete_authorization(authorization)
      assert_raise Ecto.NoResultsError, fn -> Sharepoint.get_authorization!(authorization.id) end
    end

    test "change_authorization/1 returns a authorization changeset" do
      authorization = authorization_fixture()
      assert %Ecto.Changeset{} = Sharepoint.change_authorization(authorization)
    end
  end

  describe "drives" do
    alias Wizard.Sharepoint.Drive

    @valid_attrs %{name: "some name", remote_id: "some remote_id", type: "some type", url: "some url"}
    @update_attrs %{name: "some updated name", remote_id: "some updated remote_id", type: "some updated type", url: "some updated url"}
    @invalid_attrs %{name: nil, remote_id: nil, type: nil, url: nil}

    def drive_fixture(attrs \\ %{}) do
      {:ok, drive} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Sharepoint.create_drive()

      drive
    end

    test "list_drives/0 returns all drives" do
      drive = drive_fixture()
      assert Sharepoint.list_drives() == [drive]
    end

    test "get_drive!/1 returns the drive with given id" do
      drive = drive_fixture()
      assert Sharepoint.get_drive!(drive.id) == drive
    end

    test "create_drive/1 with valid data creates a drive" do
      assert {:ok, %Drive{} = drive} = Sharepoint.create_drive(@valid_attrs)
      assert drive.name == "some name"
      assert drive.remote_id == "some remote_id"
      assert drive.type == "some type"
      assert drive.url == "some url"
    end

    test "create_drive/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sharepoint.create_drive(@invalid_attrs)
    end

    test "update_drive/2 with valid data updates the drive" do
      drive = drive_fixture()
      assert {:ok, drive} = Sharepoint.update_drive(drive, @update_attrs)
      assert %Drive{} = drive
      assert drive.name == "some updated name"
      assert drive.remote_id == "some updated remote_id"
      assert drive.type == "some updated type"
      assert drive.url == "some updated url"
    end

    test "update_drive/2 with invalid data returns error changeset" do
      drive = drive_fixture()
      assert {:error, %Ecto.Changeset{}} = Sharepoint.update_drive(drive, @invalid_attrs)
      assert drive == Sharepoint.get_drive!(drive.id)
    end

    test "delete_drive/1 deletes the drive" do
      drive = drive_fixture()
      assert {:ok, %Drive{}} = Sharepoint.delete_drive(drive)
      assert_raise Ecto.NoResultsError, fn -> Sharepoint.get_drive!(drive.id) end
    end

    test "change_drive/1 returns a drive changeset" do
      drive = drive_fixture()
      assert %Ecto.Changeset{} = Sharepoint.change_drive(drive)
    end
  end
end
