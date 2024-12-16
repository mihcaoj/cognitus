defmodule Cognitus.Repo.Migrations.RemoveUserCount do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      remove :user_count
    end
  end
end
