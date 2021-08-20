# Rummy

## Live Instance

Go to https://rummy.gigalixirapp.com

## Local Instance

To launch the application locally on port 5000:

```sh
$ docker compose run --service-ports --rm app
```

## Development

During development, it might be more convenient to use

```sh
$ docker compose run --service-ports --rm app iex -S mix phx.server
```

...since that will also give you an interactive console which lets you interact
with the application at runtime.
