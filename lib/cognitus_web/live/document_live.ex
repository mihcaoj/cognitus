defmodule CognitusWeb.DocumentLive do
  @moduledoc """
  Liveview process
  """
  use CognitusWeb, :live_view
  require Logger
  alias Cognitus.ETS_helper
  alias CognitusWeb.UsernameService

  @peers :peers
  @documents :documents

  #########################################################################
  ######################### JOIN AND LEAVE EVENTS #########################
  #########################################################################

  @doc """
  Handles a new user on the text editor software
  and returning information about peer id, document and presence.
  """
  @impl true
  def mount(_params, _session, socket) do
    # Peer handling :
    #  - Retrieve already existing peers
    #  - Insert socket ID as peer ID into the ETS table
    current_peer = socket.id
    :ets.insert(@peers, {socket.id})
    all_peers = ETS_helper.list_instances(@peers)

    # Document handling :
    #   - Create a new document for current peer
    #   - Link it to other peers document to enable synchronization
    other_peers_documents = ETS_helper.list_instances(@documents)
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
    assign(socket, :document, current_document)
    {:ok, %{socket_id: socket.id, peers: all_peers, username: username, text: current_text}, } # TODO change
    {:ok, socket}
  end

  # TODO: how to terminate ?

  # Automatically render template cognitus_web/live/document_live.html.heex

  @impl true
  def handle_event("inc_temperature", _params, socket) do
    {:noreply, update(socket, :temperature, &(&1 + 1))}
  end
  
end
