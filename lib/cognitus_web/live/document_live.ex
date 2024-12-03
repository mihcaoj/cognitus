defmodule CognitusWeb.DocumentLive do
  @moduledoc """
  Liveview process
  """
  use CognitusWeb, :live_view
  require Logger
  alias Cognitus.ETS_helper
  alias CognitusWeb.UsernameService
  alias CognitusWeb.Presence

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
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Cognitus.PubSub, "peers")

      # Generate a username and color for the user
      {username, username_color} = UsernameService.generate_username()

      # Track presence
      Presence.track(self(), "peers", socket.id,
      %{
        username: username,
        color: username_color,
        joined_at: DateTime.utc_now()
      })

      # Insert into ETS
      Logger.debug("Adding peer #{inspect(socket.id)} to ETS")
      :ets.insert(@peers, {socket.id, %{username: username, color: username_color}})
    end

    # Fetch all connected users
    users = Presence.list("peers")

    current_peer = socket.id

    # Retrieve all of the connected peers
    all_peers = ETS_helper.list_instances(@peers)

    # Document handling :
    #   - Create a new document for current peer
    #   - Link it to other peers document to enable synchronization
    other_peers_documents = ETS_helper.list_instances(@documents)
    {:ok, current_document} = Cognitus.Document.create_document()
    :ets.insert(:documents, {current_document})
    Cognitus.Document.link_with_peers_document(current_document, other_peers_documents)

    # debugging
    Logger.debug("CRDT linked with other documents: #{inspect(other_peers_documents)}")
    Logger.info("Peer #{inspect(current_peer)} has joined shared document. Peers after join: #{inspect(all_peers)}.")

    current_text = Cognitus.Document.update_text_from_document(current_document)
    Logger.debug("Sending current document text to new peer: #{inspect(current_text)}")
    # Assign the document to the socket and send the initial peer list and current username to the client
    socket =
      socket
      |> assign(:users, users)
      |> assign(:document, current_document)
      |> assign(:editing_title, false)
      |> assign(:title, "Document's title") # Default title or fetch from DB
    IO.inspect(socket)
    {:ok, socket}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: %{joins: joins, leaves: leaves}}, socket) do
    Logger.debug("Presence diff joins: #{inspect(joins)}")
    Logger.debug("Presence diff leaves: #{inspect(leaves)}")

    # Handle leaves: remove users from ETS
    Enum.each(leaves, fn {key, _value} ->
      Logger.debug("Removing peer #{key} from ETS")
      :ets.delete(:peers, key)
    end)

    # Handle joins: add users to ETS and ensure no duplicates
    Enum.each(joins, fn {key, %{metas: [latest_meta | _]}} ->
      Logger.debug("Adding #{key} in ETS with #{inspect(latest_meta)}")

      # Check for duplicate username in ETS
      :ets.insert(:peers, {key, %{username: latest_meta.username, color: latest_meta.color}})
    end)

    # Fetch the updated list of users from Presence
    users = Presence.list("peers")

    {:noreply, assign(socket, :users, users)}
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
    #current_peer_id = socket.id
    document = socket.assigns[:document]
    Cognitus.Document.delete(document, position)

    updated_text = Cognitus.Document.update_text_from_document(document)
    Logger.debug("Document state after operation LiveView: #{updated_text}")

    {:noreply, update(socket, :text, updated_text)}
  end

end
