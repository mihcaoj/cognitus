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

    Logger.info("Peer #{inspect(current_peer)} has joined shared document. Peers after join: #{inspect(all_peers)}.")

    current_text = Cognitus.Document.update_text_from_document(current_document)
    Logger.debug("Sending current document text to new peer: #{inspect(current_text)}")
    # Assign the document to the socket and send the initial peer list and current username to the client
    socket =
      socket
      |> assign(:document, current_document)
      |> assign(:editing_title, false)
      |> assign(:title, "Document's title") # Default title or fetch from DB
    IO.puts("Debug:") # TODO remove
    IO.inspect(socket)
    {:ok, socket}
  end

  # TODO: how to terminate ?

  #########################################################################
  ######################### RENDER BROWSER'S VIEW #########################
  #########################################################################

  # Automatically render template cognitus_web/live/document_live.html.heex

  #########################################################################
  ############################# HANDLE EVENTS #############################
  #########################################################################
  # -------------------------- DOCUMENT'S TITLE --------------------------
  def handle_event("edit_title", _params, socket) do
    Logger.debug("Editing title")
    IO.inspect(socket, label: "Handling edit_title")
    {:noreply, assign(socket, editing_title: true)}
  end

  def handle_event("save_title", %{"title" => new_title}, socket) do
    IO.inspect(new_title, label: "New title received")
    IO.inspect(socket, label: "Handling save_title")
    {:noreply, assign(socket, title: new_title, editing_title: false)}
  end

  def handle_event("cancel_edit_title", _params, socket) do
    IO.inspect(socket, label: "Handling cancel_edit_title")
    {:noreply, assign(socket, editing_title: false)}
  end

  # ------------------------- DOCUMENT'S UPDATE -------------------------
  @impl true
  def handle_event("insert_character", %{"ch_value" => ch_value, "position" => position}, socket) do
    current_peer_id = socket.id
    document = socket.assigns[:document]
    Cognitus.Document.insert(document, position, current_peer_id, ch_value)

    updated_text = Cognitus.Document.update_text_from_document(document)
    Logger.debug("Document state after operation LiveView: #{updated_text}")

    {:noreply, update(socket, :text, updated_text)}
  end

  @impl true
  def handle_event("delete_character", %{"position" => position}, socket) do
    current_peer_id = socket.id
    document = socket.assigns[:document]
    Cognitus.Document.delete(document, position)

    updated_text = Cognitus.Document.update_text_from_document(document)
    Logger.debug("Document state after operation LiveView: #{updated_text}")

    {:noreply, update(socket, :text, updated_text)}
  end

  
end
