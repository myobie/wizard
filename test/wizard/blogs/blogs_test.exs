defmodule Wizard.BlogsTest do
  use Wizard.DataCase

  alias Wizard.Blogs

  describe "logs" do
    alias Wizard.Blogs.Log

    @valid_attrs %{name: "some name"}
    @update_attrs %{name: "some updated name"}
    @invalid_attrs %{name: nil}

    def log_fixture(attrs \\ %{}) do
      {:ok, log} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Blogs.create_log()

      log
    end

    test "list_logs/0 returns all logs" do
      log = log_fixture()
      assert Blogs.list_logs() == [log]
    end

    test "get_log!/1 returns the log with given id" do
      log = log_fixture()
      assert Blogs.get_log!(log.id) == log
    end

    test "create_log/1 with valid data creates a log" do
      assert {:ok, %Log{} = log} = Blogs.create_log(@valid_attrs)
      assert log.name == "some name"
    end

    test "create_log/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Blogs.create_log(@invalid_attrs)
    end

    test "update_log/2 with valid data updates the log" do
      log = log_fixture()
      assert {:ok, log} = Blogs.update_log(log, @update_attrs)
      assert %Log{} = log
      assert log.name == "some updated name"
    end

    test "update_log/2 with invalid data returns error changeset" do
      log = log_fixture()
      assert {:error, %Ecto.Changeset{}} = Blogs.update_log(log, @invalid_attrs)
      assert log == Blogs.get_log!(log.id)
    end

    test "delete_log/1 deletes the log" do
      log = log_fixture()
      assert {:ok, %Log{}} = Blogs.delete_log(log)
      assert_raise Ecto.NoResultsError, fn -> Blogs.get_log!(log.id) end
    end

    test "change_log/1 returns a log changeset" do
      log = log_fixture()
      assert %Ecto.Changeset{} = Blogs.change_log(log)
    end
  end

  describe "posts" do
    alias Wizard.Blogs.Post

    @valid_attrs %{from: "some from", html: "some html", subject: "some subject"}
    @update_attrs %{from: "some updated from", html: "some updated html", subject: "some updated subject"}
    @invalid_attrs %{from: nil, html: nil, subject: nil}

    def post_fixture(attrs \\ %{}) do
      {:ok, post} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Blogs.create_post()

      post
    end

    test "list_posts/0 returns all posts" do
      post = post_fixture()
      assert Blogs.list_posts() == [post]
    end

    test "get_post!/1 returns the post with given id" do
      post = post_fixture()
      assert Blogs.get_post!(post.id) == post
    end

    test "create_post/1 with valid data creates a post" do
      assert {:ok, %Post{} = post} = Blogs.create_post(@valid_attrs)
      assert post.from == "some from"
      assert post.html == "some html"
      assert post.subject == "some subject"
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Blogs.create_post(@invalid_attrs)
    end

    test "update_post/2 with valid data updates the post" do
      post = post_fixture()
      assert {:ok, post} = Blogs.update_post(post, @update_attrs)
      assert %Post{} = post
      assert post.from == "some updated from"
      assert post.html == "some updated html"
      assert post.subject == "some updated subject"
    end

    test "update_post/2 with invalid data returns error changeset" do
      post = post_fixture()
      assert {:error, %Ecto.Changeset{}} = Blogs.update_post(post, @invalid_attrs)
      assert post == Blogs.get_post!(post.id)
    end

    test "delete_post/1 deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Blogs.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Blogs.get_post!(post.id) end
    end

    test "change_post/1 returns a post changeset" do
      post = post_fixture()
      assert %Ecto.Changeset{} = Blogs.change_post(post)
    end
  end
end
