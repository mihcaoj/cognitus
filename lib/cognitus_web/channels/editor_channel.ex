defmodule CognitusWeb.EditorChannel do
  use CognitusWeb, :channel
  require Logger
  alias CognitusWeb.UsernameService


  @peers :peers
  @documents :documents

  #########################################################################
  ######################### JOIN AND LEAVE EVENTS #########################
  #########################################################################

  @doc """
  Handles a new client joining the "editor:lobby" channel
  and returning information about peer id, document and presence.
  """
  @impl true
  def join("editor:lobby", _payload, socket) do
    # Peer handling :
    #  - Retrieve already existing peers
    #  - Insert socket ID as peer ID into the ETS table
    current_peer = socket.id
    :ets.insert(@peers, {socket.id})
    all_peers = get_all_peers()

    # Document handling :
    #   - Create a new document for current peer
    #   - Link it to other peers document to enable synchronization
    other_peers_documents = get_all_documents()
    {:ok, current_document} = Cognitus.Document.create_document()
    :ets.insert(:documents, {current_document})
    Cognitus.Document.link_with_peers_document(current_document, other_peers_documents)
    Logger.debug("CRDT linked with other documents: #{inspect(other_peers_documents)}")

    # Presence handling:
    #   - Generate a username with a corresponding color
    #   - Track the user's presence
    #   - Notify the channel to send the presence state to the client
    {username, username_color} = UsernameService.generate_username()
    #CognitusWeb.Presence.track(socket, socket.id, %{    TODO: should be corrected (error)
    #  username: username,
    #  color: username_color,
    #  joined_at: DateTime.utc_now()
    #})
    #send(self(), :after_join)

    Logger.info("Peer #{inspect(current_peer)} has joined \'editor:lobby\' channel. Peers after join: #{inspect(all_peers)}.")

    current_text = Cognitus.Document.update_text_from_document(current_document)
    Logger.debug("Sending current document text to new peer: #{inspect(current_text)}")
    # Assign the document to the socket and send the initial peer list and current username to the client
    {:ok, %{socket_id: socket.id, peers: all_peers, username: username, text: current_text}, assign(socket, :document, current_document)}
  end

  @doc """
  Handles a client leaving the channel.

  - Removes the client's socket ID from the global peer list
  - Broadcasts the updated peer list to all connected clients
  """
  @impl true
  def terminate(_reason, socket) do
    # Peer handling :
    #   - Delete current peer from peers list
    #   - Broadcast new peers list to all clients subscribed to the channel
    current_peer = socket.id
    :ets.delete(:peers, current_peer)
    remaining_peers = get_all_peers()
    broadcast!(socket, "peer_list_updated", %{"peers" => remaining_peers})
    Logger.info("Peer #{inspect(current_peer)} has left \'editor:lobby\' channel. Peers after leaving: #{inspect(remaining_peers)}.")

    # Document handling :
    #   - Delete current peer's document from documents list
    #   - Broadcast new documents list to all clients subscribed to the channel
    :ets.delete(:documents, socket.assigns[:document])
    documents = get_all_documents() |> Enum.map(fn doc -> %{id: inspect(doc)} end)
    broadcast!(socket, "document_list_updated", %{"documents" => documents})

    :ok
  end

  @doc """
  # Push the current presence state to the client

  - Retrieves the list of current presences for the channel/topic
  - Send this list to the client via "presence_state" event
  """
  @impl true
  def handle_info(:after_join, socket) do
    push(socket, "presence_state", CognitusWeb.Presence.list(socket.topic))

    Logger.info("Sent presence to #{socket.id}")

    {:noreply, socket}
  end
  #########################################################################
  ######################### WEBRTC SIGNALING HANDLERS #####################
  #########################################################################
  @doc """
  Handles incoming WebRTC offer from a client.

  - Receives a WebRTC offer from a client and forwards it to the intended peer
  - This is the initial step in establishing a peer-to-peer connection

  Parameters:
  - `offer`: The WebRTC SDP offer from the client
  - `to`: The target peer's socket ID
  """
  @impl true
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
  @impl true
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
  @impl true
  def handle_in("ice_candidate", %{"candidate" => candidate, "to" => peer_id}, socket) do
    Logger.info("Received ICE candidate from #{socket.id} for peer #{peer_id}")

    if peer_id do
      broadcast!(socket, "ice_candidate", %{"candidate" => candidate, "from" => socket.id, "to" => peer_id})
    else
      Logger.error("ICE candidate received with no peer_id")
    end

    {:noreply, socket}
  end
  #####################################################################################
  ######################### INSERTION AND DELETION OPERATIONS #########################
  #####################################################################################
  # Treat an "insertion" event - A character is added
  @impl true
  def handle_in("insert", %{"source" => source, "ch_value" => ch_value, "position" => position}, socket) do
    current_peer_id = socket.id
    if source==current_peer_id do
      document = socket.assigns[:document]
      Cognitus.Document.insert(document, position, current_peer_id, ch_value)
      #Cognitus.Document.update_text_from_document(document)

      updated_text = Cognitus.Document.update_text_from_document(document)
      Logger.debug("Document state after operation: #{updated_text}")
    end

    {:noreply, socket}
  end

  # Treat a "deletion" event - A character is deleted
  @impl true
  def handle_in("delete", %{"source" => source, "position" => position}, socket) do
    current_peer_id = socket.id
    if source == current_peer_id do
      document = socket.assigns[:document]
      Cognitus.Document.delete(document, position)
      #Cognitus.Document.update_text_from_document(document)

      updated_text = Cognitus.Document.update_text_from_document(document)
      Logger.debug("Document state after operation: #{updated_text}")
    end

    {:noreply, socket}
  end

  #########################################################################
  ######################### HELPER FUNCTIONS  #############################
  #########################################################################

  # Helper function to retrieve all peers
  # - Fetches the list of all connected peers from the ETS table
  # - The peer list is stored as tuples `{peer_id}` and flattened into a list of peer IDs
  defp get_all_peers do
    :ets.tab2list(@peers) |> Enum.map(fn {peer_id} -> peer_id end)
  end

  # Helper function to retrieve all peers document
  # - Fetches the list of all connected peers's documents from the ETS table
  # - The peer list is stored as tuples `{ document}` and flattened into a list of documents (CRDT instances)
  defp get_all_documents do
    :ets.tab2list(:documents) |> Enum.map(fn {document} -> document end)
  end

end
