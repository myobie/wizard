defmodule WizardWeb.FeedView do
  use WizardWeb, :view

  def format_file_name(%{payload: payload}) do
    ~E"""
    <a href="<%= payload["url"] %>"><%= payload["name"] %></a>
    """
  end

  def format_actor(actor) do
    ~E"""
    <a href="mailto:<%= actor.email %>"><%= actor.name %></a>
    """
  end

  def format_actors([actor]),
    do: format_actor(actor)

  def format_actors([actor1, actor2]) do
    ~E"""
    <%= format_actor(actor1) %>
    and
    <%= format_actor(actor2) %>
    """
  end

  def format_actors(actors) do
    format_actors(~E"", actors)
  end

  def format_actors(result, [_, _] = actors) do
    ~E"""
    <%= result %>, <%= format_actors(actors) %>
    """
  end

  def format_actors(result, [actor | actors]) do
    result = ~E"""
             <%= result %>, <%= format_actor(actor) %>
             """

    format_actors(result, actors)
  end
end
