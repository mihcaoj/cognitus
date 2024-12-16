defmodule Cognitus.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents) do
      add :title, :string
      add :content, :text
      add :user_count, :integer, default: 0
      timestamps()
    end
  end
end
