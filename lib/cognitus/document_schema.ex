defmodule Cognitus.DocumentSchema do
@moduledoc """
Schema for document persistence in the database.
Stores document information including:
- title: The document title
- content: The text content of the document
- timestamps: When the document was created and last modified
"""
  use Ecto.Schema
  import Ecto.Changeset

  # Define database schema for storing documents
  # Creates a table with title, content, and automatic timestamps
  schema "documents" do
    field :title, :string
    field :content, :string
    timestamps()
  end

  # Validates and prepares changes to document records
  # Params:
  #   document - The document struct to be changed
  #   attrs - Map of attributes to update
  def changeset(document, attrs) do
    document
    |> cast(attrs, [:title, :content]) # Only these fields can be modified
    |> validate_required([:title]) # Document must have a title
  end
end
