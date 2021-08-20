# Rummy

To launch the application on port 5000:

```sh
$ docker compose run --rm app
```

During development, it might be more convenient to use

```sh
$ docker compose run --rm app iex -S mix phx.server
```

...since that will also give you an interactive console which lets you interact
with the application at runtime.
