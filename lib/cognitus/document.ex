defmodule Cognitus.Document do
  defstruct content: [] # Simple list placeholder for the future CRDT implementation

  def insert(%__MODULE__{content: content} = document, id, char, position) do
    new_content = content |> List.insert_at(position, %{id: id, char: char})

    %__MODULE__{document | content: new_content}
  end

  def delete(%__MODULE__{content: content} = document, id) do
    new_content = Enum.reject(content, fn item -> item.id == id end)
    %__MODULE__{document | content: new_content}
  end
end
