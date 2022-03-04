defmodule RummyWeb.IexShellLive do
  @moduledoc false

  use RummyWeb, :live_view

  alias Phoenix.LiveView.JS

  def mount(_session, _params, socket) do
    {:ok, tty} = ExTTY.start_link(handler: self())
    {:ok, assign(socket, tty: tty)}
  end

  def show_terminal(js \\ %JS{}) do
    js
    |> JS.show(to: "#terminal")
    |> JS.hide(to: "#hood")
  end

  def render(assigns) do
    ~H"""
    <div id="hood" style="text-align: center; margin-top: 3em" phx-click={show_terminal()}>Peek under the hood...</div>
    <div id="terminal" style="display: none; margin: 39px; margin-right: 24px; box-shadow: 0px 0px 0px 8px #000000, 0px 0px 0px 16px #4B4C4B, 0px 0px 0px 24px #828482, 0px 0px 0px 31px #B2B5B2, 0px 0px 0px 39px #DADDDA, 5px 5px 15px 5px rgba(0,0,0,0);" phx-update="ignore" phx-hook="Terminal"></div>
    """
  end

  def handle_info({:tty_data, data}, socket) do
    {:noreply, push_event(socket, "print", %{data: data})}
  end

  def handle_event("key", %{"key" => key}, %{assigns: %{tty: tty}} = socket) do
    ExTTY.send_text(tty, key)
    {:noreply, socket}
  end
end
