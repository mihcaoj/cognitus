defmodule CognitusWeb.PageController do
  use CognitusWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end
end

# TODO: delete because we use LiveView instead of controllers
