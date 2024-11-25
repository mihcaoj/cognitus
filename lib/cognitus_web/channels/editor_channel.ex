defmodule CognitusWeb.EditorChannel do
  use CognitusWeb, :channel
  require Logger

  @peers :peers

  #########################################################################
  ######################### JOIN AND LEAVE EVENTS #########################
  #########################################################################

  @doc """
  Handles a new client joining the "editor:lobby" channel.

  - Adds the client's socket ID to the global peer list stored in ETS (Erlang Term Storage)
  - Fetches the updated list of peers and sends it to the client
  - Initializes a shared document for collaboration
  """
  @impl true
  def join("editor:lobby", _payload, socket) do
    document = %Cognitus.Document{}

    # List of famous computer scientist names
    all_usernames = [
        "Alan Turing", "Donald Knuth", "Tim Berners-Lee", "John McCarthy",
        "Edsger Dijkstra", "Grace Hopper", "Claude Shannon", "Linus Torvalds",
        "John von Neumann", "Barbara Liskov", "Bjarne Stroustrup", "Guido van Rossum",
        "Vint Cerf", "Dennis Ritchie", "Ken Thompson", "Alan Kay", "Marvin Minsky",
        "Niklaus Wirth", "Andrew Tanenbaum", "Douglas Engelbart", "Ada Lovelace",
        "Margaret Hamilton", "Leslie Lamport", "Stephen Wolfram", "James Gosling",
        "Betty Holberton", "Adele Goldberg", "Larry Page", "Bill Gates"
      ]

    # - Retrieves the list of usernames currently in use using Presence
    # - Enum.flat_map iterates through this map and extracts all usernames from the metas list for each user
    # - The comprehension loop extracts the username key from each metadata map
    # - do: username collects all extracted usernames in a flat list
    assigned_usernames =
      CognitusWeb.Presence.list("editor:lobby")
      |> Enum.flat_map(fn {_id, %{metas: metas}} -> for %{username: username} <- metas, do: username end)

    # Calculate available usernames
    available_usernames = all_usernames -- assigned_usernames

    # Assign a username
    # - If list is empty return an error message
    # - Otherwise take the head of the list and assign it
    username =
      case available_usernames do
        [] -> Logger.error("No usernames available!")

        [uname | _rest] -> uname
      end

    # Insert the socket ID into the ETS table
    :ets.insert(@peers, {socket.id})

    # Get the current list of peers
    peers = get_all_peers()

    Logger.info("Peers after join: #{inspect(peers)}")

    # Call the helper function to generate a color and store it
    color = generate_color()

    # Track the user's presence
    CognitusWeb.Presence.track(socket, socket.id, %{
      username: username,
      color: color,
      joined_at: DateTime.utc_now()
    })

    # Notify the channel to send the presence state to the client
    send(self(), :after_join)

    # Assign the document to the socket and send the initial peer list to the client
    {:ok, %{socket_id: socket.id, peers: peers, username: username}, assign(socket, :document, document)}
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

  @doc """
  # Push the current presence state to the client

  - Retrieves the list of current presences for the channel/topic
  - Send this list to the client via "presence_state" event
  """
  @impl true
  def handle_info(:after_join, socket) do
    push(socket, "presence_state", CognitusWeb.Presence.list(socket.topic))

    Logger.info("sent presence to #{socket.id}")

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

  #########################################################################
  ######################### HELPER FUNCTIONS  #############################
  #########################################################################

     # Helper function to retrieve all peers
    # - Fetches the list of all connected peers from the ETS table
    # - The peer list is stored as tuples `{peer_id}` and flattened into a list of peer IDs
    defp get_all_peers do
      :ets.tab2list(@peers) |> Enum.map(fn {peer_id} -> peer_id end)
    end

    # Helper function to generate a unique color for the user's username
    defp generate_color() do
      adjust = fn -> Enum.random(1..255) end

      # generate RGB values in the adjusted range
      r = adjust.()
      g = adjust.()
      b = adjust.()

      # return the generated color in RGB format
      "rgb(#{r}, #{g}, #{b})"
    end

end
