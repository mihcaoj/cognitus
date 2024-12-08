defmodule Cognitus.Document do
  require Logger
  @moduledoc """
  Document is structured as a `AWLWWMap`, where
  keys are character's id {logical_position, peer_id}
  and values are the characters' value.
  Order of characters is given by character's id.
  """
  @type ch_id :: {float(), integer()}
  @type ch :: {ch_id(), char()}
  @type document :: DeltaCrdt.t()

  @spec create_document() :: GenServer.on_start()
  @doc """
  Create a OR-Set CRDT document data structure.
  """
  def create_document() do
    DeltaCrdt.start_link(DeltaCrdt.AWLWWMap, sync_interval: 100)
  end

  @spec link_documents(document(), [document()]) :: :ok
  @doc """
  Link replicas of two peers
  """
  def link_documents(new_document, others_document) do
    DeltaCrdt.set_neighbours(new_document, others_document)
    Enum.map(others_document, fn other_document ->
      DeltaCrdt.set_neighbours(other_document,[new_document])
      inspect(DeltaCrdt.to_map(other_document))  # TODO Remove
    end)
    Logger.debug("Linked new CRDT #{inspect(new_document)} with other's CRDT: #{inspect(others_document)}")
    Process.sleep(10) # need to wait for propagation for the doctest TODO remove
    DeltaCrdt.to_map(new_document) # TODO Remove
  end

  @spec insert(document(), integer(), integer(), char()) :: document()
  @doc """
  Add a character to text document given its physical position.
  """
  def insert(document, position, peer_id, ch_value) do
    Logger.debug("CRDT state before insert: #{inspect(DeltaCrdt.to_map(document))}")

    prev_ch_id = if position >= 1, do: get_ch_id_at_position(document, position - 1), else: nil
    next_ch_id = get_ch_id_at_position(document, position)
    ch_id = generate_ch_id(peer_id, prev_ch_id, next_ch_id)
    DeltaCrdt.put(document, ch_id, ch_value)
    Logger.debug("CRDT state after insert: #{inspect(DeltaCrdt.to_map(document))}")
  end

  @spec delete(document(), ch_id()) :: document()
  @doc """
  Delete a character from text document given its physical position
  """
  def delete(document, position) do
    ch_id = get_ch_id_at_position(document, position)
    ch_value = DeltaCrdt.get(document, ch_id)
    DeltaCrdt.delete(document, ch_id)
    ch_value
  end

  @spec update_text_from_document(document()) :: String.t()
  # Convert the CRDT document into the corresponding text
  def update_text_from_document(document) do
    sorted_ch_ids =
      document
      |> DeltaCrdt.to_map()
      |> Map.keys()
      |> Enum.sort()
    list_of_ch = Enum.map(sorted_ch_ids, fn ch_id -> DeltaCrdt.get(document, ch_id) end)
    Enum.join(list_of_ch)
  end

  @spec generate_ch_id(integer(), ch_id(), ch_id()) :: ch_id()
  # Generate character unique identifier {logical_position, peer_id} for which
  # logical position is calculated based on previous and next characters.
  # If character:
  # - is first character to be inserted (no predecessor, no successor), it has logical position 100
  # - is before first character (no predecessor), it takes logical position successor_logical_position - 10
  # - is after last character (no successor), it takes logical position predecessor_logical_position + 10
  # - is between two characters, its logical position is the average of both
  # Parameters:
  # - peer_id
  # - predecessor character's ch_id
  # - successor character's ch_id
  defp generate_ch_id(peer_id, nil, nil), do: {100, peer_id}
  defp generate_ch_id(peer_id, nil, {next_log_pos, _}), do: {next_log_pos - 10, peer_id}
  defp generate_ch_id(peer_id, {prev_log_pos, _}, nil), do: {prev_log_pos + 10, peer_id}
  defp generate_ch_id(peer_id, {prev_log_pos, _}, {next_log_pos, _}) do
    {(prev_log_pos + next_log_pos)/2, peer_id}
  end

  @spec get_ch_id_at_position(document(), integer()) :: ch_id()
  # Retrieve identifier of a character given its position.
  defp get_ch_id_at_position(document, position) do
    sorted_ch_ids =
      document
      |> DeltaCrdt.to_map()
      |> Map.keys()
      |> Enum.sort()
    Enum.at(sorted_ch_ids, position)
  end
 end
