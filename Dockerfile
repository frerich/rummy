FROM elixir:1.12.2-alpine

# * inotify-tools is needed to make fileystem watching (for rebuilds) work
# * nodejs and yarn are used by the application's build process
RUN apk update && \
  apk add inotify-tools nodejs yarn

# Install Hex package manager and rebar (the Erlangbuild toool)
RUN mix local.rebar --force && mix local.hex --force
