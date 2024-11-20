defmodule CognitusWeb.EditorChannel do
  use CognitusWeb, :channel
  require Logger

  # Keep a list of connected peers
  @peers :ets.new(:peers, [:named_table, :public, read_concurrency: true]) # TODO pourquoi on l'a defini deux fois ? Egalement dans application.ex

  ################################################################################################
  # Join and Leave events
  ################################################################################################

  @doc """
  Handles a new client joining the "editor:lobby" channel.

  - Adds the client's socket ID to the global peer list stored in ETS (Erlang Term Storage)
  - Fetches the updated list of peers and sends it to the client
  - Initializes a shared document for collaboration
  """
  @impl true
  def join("editor:lobby", _payload, socket) do
    {:ok, document} = Cognitus.Document.create_document()

    :ets.insert(@peers, {socket.id, document})

    # Get the current list of peers
    peers = get_all_peers()
    Logger.info("Peers after join: #{inspect(peers)}")

    # Link their CRDT document replicas
    Cognitus.Document.link_peers_document(document, peers_documents)

    # Assign the document to the socket and send the initial peer list to the client
    {:ok, %{socket_id: socket.id, peers: peers}, assign(socket, :document, document)}
  end

  @doc """
  Handles a client leaving the channel.

  - Removes the client's socket ID from the global peer list
  - Broadcasts the updated peer list to all connected clients
  """
  @impl true
  def terminate(_reason, socket) do
    :ets.delete(@peers, socket.id)

    peers = get_all_peers()
    broadcast!(socket, "peer_list_updated", %{"peers" => peers})

    Logger.info("Peers after leave: #{inspect(peers)}")
    :ok
  end

  # Helper function to retrieve all peers
  # - Fetches the list of all connected peers from the ETS table
  # - The @peers list is stored as tuples `{peer_id, document}` and flattened into a list of peer IDs
  defp get_all_peers do
    :ets.tab2list(@peers) |> Enum.map(fn {peer_id, _} -> peer_id end)
  end

  # Helper function to retrieve all peers document
  # - Fetches the list of all connected peers's documents from the ETS table
  # - The peer list is stored as tuples `{peer_id, document}` and flattened into a list of documents (CRDT instances)
  defp get_all_peers do
    :ets.tab2list(@peers) |> Enum.map(fn {_peer_id, document} -> document end)
  end

  ################################################################################################
  # WebRTC signaling handlers
  ################################################################################################

  @doc """
  Handles incoming WebRTC offer from a client.

  - Receives a WebRTC offer from a client and forwards it to the intended peer
  - This is the initial step in establishing a peer-to-peer connection

  Parameters:
  - `offer`: The WebRTC SDP offer from the client
  - `to`: The target peer's socket ID
  """
  def handle_in("webrtc_offer", %{"offer" => offer, "to" => peer_id}, socket) do
    Logger.info("Received WebRTC offer from #{socket.id} for peer #{peer_id}")

    if peer_id do
      broadcast!(socket, "webrtc_offer", %{"offer" => offer, "from" => socket.id, "to" => peer_id})
      Logger.info("Broadcasted WebRTC offer to peer #{peer_id}")
    else
      Logger.error("WebRTC offer received with no peer_id")
    end

    {:noreply, socket}
  end

  # Handles incoming WebRTC answer from a client.
  # - Forwards the answer to the initiating peer to finalize the peer-to-peer connection
  #
  # Parameters:
  # - `answer`: The WebRTC SDP answer from the client
  # - `to`: The target peer's socket ID
  def handle_in("webrtc_answer", %{"answer" => answer, "to" => peer_id}, socket) do
    Logger.info("Received WebRTC answer from #{socket.id} for peer #{peer_id}")

    if peer_id do
      broadcast!(socket, "webrtc_answer", %{"answer" => answer, "from" => socket.id, "to" => peer_id})
    else
      Logger.error("WebRTC answer received with no peer_id")
    end
    {:noreply, socket}
  end


  # Handles incoming ICE candidate from a client.
  # - ICE candidates are sent by peers to share network information (used to establish the connection)
  #
  # Parameters:
  # - `candidate`: The ICE candidate from the client
  # - `to`: The target peer's socket ID
  def handle_in("ice_candidate", %{"candidate" => candidate, "to" => peer_id}, socket) do
    Logger.info("Received ICE candidate from #{socket.id} for peer #{peer_id}")

    if peer_id do
      broadcast!(socket, "ice_candidate", %{"candidate" => candidate, "from" => socket.id, "to" => peer_id})
    else
      Logger.error("ICE candidate received with no peer_id")
    end
    {:noreply, socket}
  end

  ################################################################################################
  # Automatically generated - not modified
  ################################################################################################

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (editor:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  #defp authorized?(_payload) do
  #  true
  #end
end
