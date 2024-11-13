@doc '''
Document is structured as a `AWLWWMAP` where keys are character's id
and values are tuples {character, position}

id is a tuple {process_nr, insertion_nr}
'''
defmodule Cognitus.Document do
  @defstruct id = {Integer, Integer}

  # Insertion counter
  counter = 0

  # Start an OR-Set CRDT.
  {:ok, document_text} = DeltaCrdt.start_link(DeltaCrdt.AWLWWMap)

  def insert(crdt_pid, id, char, position) do
    key = {id}  # Using a tuple to ensure unique keys
    value = {char, position}
    DeltaCrdt.mutate(crdt_pid, :add, [key, value])
  end

  def getTextContent(crdt_pid) do
    positions = document_text.keys()
  end
  '''
  OLD version
  defstruct content: [] # Simple list placeholder for the future CRDT implementation

  def insert(%__MODULE__{content: content} = document, id, char, position) do
    new_content = content |> List.insert_at(position, %{id: id, char: char})

    %__MODULE__{document | content: new_content}
  end

  def delete(%__MODULE__{content: content} = document, id) do
    new_content = Enum.reject(content, fn item -> item.id == id end)
    %__MODULE__{document | content: new_content}
  end

  '''
end
