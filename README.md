# Wizard

## License

<https://nathan.mit-license.org>

## Development

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Authentication with Microsoft

You will need a public URL to your private machine. This can be done with
[forward](https://forwardhq.com). You will need to remember to
`forward 0.0.0.0:4000` so it works with the latest Mac OS X.

You will also need to have created an AAD application and created a
`dev.secret.exs` file like so:

```ex
use Mix.Config

config :wizard,
  aad_client_id: "xxx",
  aad_client_secret: "xxx",
  aad_redirect_url: "https://yoursubdomain.fwd.wf/authentication/callback"
```

Then you can visit `https://yoursubdomain.fwd.wf/signin` to create the
authorization and user records. After that you can do API calls without using
`forward`.

## Tests

There aren't any right now. Sorry.
