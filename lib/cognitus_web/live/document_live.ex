defmodule CognitusWeb.DocumentLive do
  @moduledoc """
  Liveview process for document
  """
  use CognitusWeb, :live_view
  require Logger
  alias Cognitus.PresenceHelper
  alias Cognitus.Document
  alias Cognitus.DocumentTitleAgent
  alias Cognitus.PubSub
  alias CognitusWeb.UsernameService
  alias CognitusWeb.Presence

  #########################################################################
  #################### MOUNTING (JOIN & LEAVE EVENTS) #####################
  #########################################################################

  @doc """
  Handles a new user on the text editor software
  and returning information about peer id, document and presence.
  """
  @impl true
  def mount(_params, _session, socket) do
    others_document = PresenceHelper.list_instances(:document)

    # Generate a username, a color and a document for the new user
    {username, username_color} = UsernameService.generate_username()
    {:ok, document} = Document.create_document()

    if connected?(socket) do
      # Subscribe to PubSub for title and user updates
      topics = ["title_updates", "users", "document_updates"]
      Enum.map(topics, fn topic -> Phoenix.PubSub.subscribe(PubSub, topic) end)

      # Debugging TODO: REMOVE
      Logger.debug("#{username}'s socket is connected and user is subscribed to topics #{inspect(topics)}")

      # Track user presence
      Presence.track(self(), "users", socket.id,
      %{
        username: username,
        color: username_color,
        document: document
      })
    end

    # Fetch all connected users
    users = Presence.list("users")

    # Link CRDT documents
    Document.link_documents(document, others_document)

    # Debugging TODO: REMOVE
    IO.puts("Current Document Map:")
    IO.inspect(DeltaCrdt.to_map(document))
    IO.puts("OTHER USERS DOCUMENT")
    IO.inspect(others_document)
    IO.puts("CURRENT DOCUMENT")
    IO.inspect(document)
    Logger.info("#{username} has joined shared document. Users after join: #{inspect(PresenceHelper.list_instances(:username))}.")

    current_text = Document.update_text_from_document(document)

    # Debugging TODO: REMOVE
    Logger.debug("Sending current document text to new user: #{inspect(current_text)}")

    # Initialize socket with initial state:
    # - connected users list
    # - current user's username
    # - CRDT document reference
    # - title editing flag
    # - current document title
    # - current document text
    socket =
      socket
      |> assign(:users, users)
      |> assign(:username, username)
      |> assign(:document, document)
      |> assign(:editing_title, false)
      |> assign(:title, DocumentTitleAgent.get_title())
      |> assign(:text, current_text)
    {:ok, socket}
  end

  #########################################################################
  ############################### HANDLERS ################################
  #########################################################################

  # -------------------------- PRESENCE DIFFS --------------------------
  @impl true
  def handle_info(%{event: "presence_diff", payload: %{joins: _joins, leaves: _leaves}}, socket) do
    # Fetch the updated list of users from Presence
    users = Presence.list("users")

    {:noreply, assign(socket, :users, users)}
  end

  # -------------------------- DOCUMENT TITLE --------------------------
  # Handling event "Enter document's title edition mode"
  def handle_event("edit_title", _params, socket) do
    Logger.info("#{socket.assigns[:username]} has entered in title edition mode.")
    {:noreply, assign(socket, editing_title: true)}
  end

  # Handling event "Save a new document's title"
  def handle_event("save_title", %{"title" => new_title}, socket) do
    DocumentTitleAgent.set_title(new_title)
    # Broadcast the new title to all of the connected clients
    Phoenix.PubSub.broadcast(
      PubSub,
      "title_updates",
      %{event: "title_updated", title: new_title}
    )

    Logger.info("#{socket.assigns[:username]} has saved new title: #{new_title}}.")

    # Update the title locally
    {:noreply, assign(socket, title: new_title, editing_title: false)}
  end

  # Handling event "Quit document's title edition mode without saving modification"
  def handle_event("cancel_edit_title", _params, socket) do
    Logger.info("#{socket.assigns[:username]} cancelled title edition.")
    {:noreply, assign(socket, editing_title: false)}
  end

  # Synchronise document's title when another user updated it.
  @impl true
  def handle_info(%{event: "title_updated", title: new_title}, socket) do
    # Update the title
    {:noreply, assign(socket, title: new_title)}
  end

  # -------------------------- DOCUMENT UPDATES --------------------------
  # Handling event "insertion of a character"
  @impl true
  def handle_event("insert_character", %{"ch_value" => ch_value, "position" => position}, socket) do
    current_peer_id = socket.id
    document = socket.assigns[:document]
    Document.insert(document, position, current_peer_id, ch_value)
    updated_text = Document.update_text_from_document(document)

    # Broadcast the update to all of the LiveView processes
    Phoenix.PubSub.broadcast(
      PubSub,
      "document_updates",
      %{event: "text_updated", text: updated_text}
    )

    # Debugging (TODO: REMOVE WHEN FINISHED IMPLEMENTING)
    Logger.info("#{socket.assigns[:username]} has inserted character #{ch_value} at position #{position}.")
    Logger.debug("Document state of #{socket.assigns[:username]} after insertion operation: #{updated_text}")

    # Update this LiveView process's state with the updated text
    {:noreply, assign(socket, :text, updated_text)}
  end

  # Handling event "deletion of a character"
  @impl true
  def handle_event("delete_character", %{"position" => position}, socket) do
    document = socket.assigns[:document]
    ch_value = Document.delete(document, position)
    updated_text = Document.update_text_from_document(document)

    # Broadcast the update to all of the LiveView processes
    Phoenix.PubSub.broadcast(
      PubSub,
      "document_updates",
      %{event: "text_updated", text: updated_text}
    )

    # Debugging (TODO: REMOVE WHEN FINISHED IMPLEMENTING)
    Logger.info("#{socket.assigns[:username]} has deleted character #{ch_value} at position #{position}.")
    Logger.debug("Document state of #{socket.assigns[:username]} after deletion operation: #{updated_text}")

    # Update this LiveView process's state with the updated text
    {:noreply, assign(socket, :text, updated_text)}
  end

  # Handling info for "text updates"
  # This gets called in all of the LiveView processes when they receive the PubSub broadcast
  @impl true
  def handle_info(%{event: "text_updated", text: updated_text}, socket) do
    Logger.debug("Received updated text: #{updated_text}") # TODO: REMOVE
    # Update the LiveView process's socket assigns with the updated text
    socket = assign(socket, :text, updated_text)
    # Push the text update to the client connected to this LiveView process
    # Without this, the UI wouldn't update in real-time for other users
    # Even though the CRDT syncs server state, we need this to sync the UI
    {:noreply, push_event(socket, "text_updated", %{text: updated_text})}
  end
end
