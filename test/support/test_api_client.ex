defmodule Wizard.TestApiClient.Request do
  defstruct verb: "GET", url: "/", opts: [], body: nil, response: nil
end

defmodule Wizard.TestApiClient do
  use Wizard.ApiClient
  alias Wizard.TestApiClient.Request

  @server Wizard.TestApiClient.Server

  def start_link,
    do: GenServer.start_link(@server, [], [name: @server])

  def get(url, opts \\ []) do
    %Request{verb: :GET, url: url, opts: opts}
    |> find_match()
    |> format_response()
  end

  def post(url, body, opts \\ []) do
    %Request{verb: :POST, url: url, opts: opts, body: body}
    |> find_match()
    |> format_response()
  end

  def post_form(url, body, opts \\ []) do
    %Request{verb: :POST, url: url, opts: opts, body: body}
    |> find_match()
    |> format_response()
  end

  def delete(url, opts \\ []) do
    %Request{verb: :DELETE, opts: opts, url: url}
    |> find_match()
    |> format_response()
  end

  def clear, do: GenServer.call(@server, :clear)

  def match(verb, url_regex, response),
    do: GenServer.call(@server, {:append, verb, url_regex, response})

  def match_with(fun) when is_function(fun),
    do: GenServer.call(@server, {:append, fun})

  defmacro match([do: fun]) do
    quote do: unquote(__MODULE__).match_with(unquote(fun))
  end

  defp format_response(response) do
    case response do
      nil -> {:error, :no_matcher_for_request}
      res -> res
    end
  end

  defp find_match(req),
    do: GenServer.call(@server, {:match, req})
end

defmodule Wizard.TestApiClient.Server do
  use GenServer

  def init(_),
    do: {:ok, %{matchers: []}}

  def handle_call(:clear, _from, state),
    do: {:reply, :ok, %{state | matchers: []}}

  def handle_call({:append, fun}, _from, %{matchers: matchers} = state) do
    {:reply,
     :ok,
     %{state | matchers: List.insert_at(matchers, 0, fun)}}
  end

  def handle_call({:append, verb, url_regex, response}, from, state) do
    fun = fn req ->
      if req.verb == verb && Regex.match?(url_regex, req.url) do
        {:ok, response}
      end
    end

    handle_call({:append, fun}, from, state)
  end

  def handle_call({:match, req}, _from, %{matchers: matchers} = state) do
    {:reply,
     matches(req, matchers).response,
     state}
  end

  def matches(req, [matcher | matchers]) do
    case matcher.(req) do
      {:ok, response} -> %{req | response: response}
      _ -> matches(req, matchers)
    end
  end

  def matches(req, []), do: req
end
