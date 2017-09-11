FROM elixir:1.5.1

MAINTAINER Nathan Herald

RUN curl -sL https://deb.nodesource.com/setup_8.x | bash - && \
    apt-get install nodejs -y

ENV MIX_ENV=prod

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.info

WORKDIR /app
RUN mkdir config

COPY mix.exs mix.lock /app/
COPY config/config.exs config/prod.exs config/prod.secret.exs /app/config/

RUN mix deps.get

COPY lib /app/lib/
COPY priv /app/priv/
COPY rel /app/rel/

RUN mix compile

COPY assets/package.json assets/package-lock.json /app/assets/

WORKDIR /app/assets

RUN npm install

COPY assets /app/assets/
RUN /app/assets/node_modules/brunch/bin/brunch build --production

WORKDIR /app

RUN mix phx.digest
RUN mix release --env=prod
