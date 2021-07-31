defmodule RummyWeb.PageLiveTest do
  use RummyWeb.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "Want to play a game?"
    assert render(page_live) =~ "Want to play a game?"
  end
end
