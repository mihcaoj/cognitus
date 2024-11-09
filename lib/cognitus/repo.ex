defmodule Cognitus.Repo do
  use Ecto.Repo,
    otp_app: :cognitus,
    adapter: Ecto.Adapters.Postgres
end
