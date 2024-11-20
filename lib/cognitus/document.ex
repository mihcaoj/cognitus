defmodule Cognitus.Document do
  @moduledoc """
  Document is structured as a `AWLWWMAP` where
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
    {:ok, document} = DeltaCrdt.start_link(DeltaCrdt.AWLWWMap)
  end

  @spec link_peers_document(document(), [document()]) :: :ok
  @doc """
  Link replicas of two peers
  """
  def link_peers_documents(current_peer_document, other_peer_documents_list) do
    DeltaCrdt.set_neighbours(current_peer_document, [another_peer_document])
  end

  @spec insert(document(), ch(), ch(), integer(), char()) :: document()
  @doc """
  Add a character to text document
  """
  def insert(document, {prev_ch_id, _prev_ch_value}, {next_ch_id, _next_ch_value}, peer_id, ch_value) do
    ch_id = generate_ch_id(peer_id, prev_ch_id, next_ch_id)
    DeltaCrdt.put(document, ch_id, ch_value)
  end

  @spec delete(document(), ch_id()) :: document()
  @doc """
    Delete a character by its ID
  """
  def delete(document, ch_id) do
    DeltaCrdt.remove(document, ch_id)
  end

  @spec generate_ch_id(integer(), ch_id(), ch_id()) :: ch_id()
  @doc """
  Generate character unique identifier {logical_position, peer_id} for which
  logical position is calculated based on previous and next characters.
  If character:
  - is first character to be inserted (no predecessor, no successor), it has logical position 100
  - is before first character (no predecessor), it takes logical position successor_logical_position - 10
  - is after last character (no successor), it takes logical position predecessor_logical_position + 10
  - is between two characters, its logical position is the average of both

  Parameters:
  - peer_id
  - predecessor character's ch_id
  - successor character's ch_id
  """
  defp generate_ch_id(peer_id, nil, nil), do: {100, peer_id}
  defp generate_ch_id(peer_id, nil, {next_log_pos, _} = next_id), do: {next_log_pos + 10, peer_id}
  defp generate_ch_id(peer_id, {prev_log_pos, _} = prev_id, nil), do: {prev_log_pos - 10, peer_id}
  defp generate_ch_id(peer_id, {prev_log_pos, _} = prev_id, {next_log_pos, _} = next_id) do
    {(prev_log_post + next_log_pos)/2, peer_id}
  end
end
