defmodule CognitusWeb.DocumentLive do
  @moduledoc """
  Liveview process for document
  """
  use CognitusWeb, :live_view
  require Logger
  alias Cognitus.PresenceHelper
  alias CognitusWeb.UsernameService
  alias CognitusWeb.Presence

  #########################################################################
  ######################### JOIN AND LEAVE EVENTS #########################
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
    {:ok, document} = Cognitus.Document.create_document()

    if connected?(socket) do
      # Subscribe to PubSub for title and peers updates
      topics = ["title_updates","peers"]
      Enum.map(topics, fn topic -> Phoenix.PubSub.subscribe(Cognitus.PubSub, topic) end)
      Logger.debug("#{username}'s socket is connected and user is subscribed to topics #{inspect(topics)}")

      # Track presence
      Presence.track(self(), "peers", socket.id,
      %{
        username: username,
        color: username_color,
        document: document,
        joined_at: DateTime.utc_now()   # TODO Final cleanup: remove unless we use it
      })
    end

    # Fetch all connected users
    users = Presence.list("peers")

    # Link CRDT documents
    Cognitus.Document.link_with_peers_document(document, others_document)

    IO.puts("OTHER PEERS DOCUMENT") # TODO remove
    IO.inspect(others_document)
    IO.puts("CURRENT DOCUMENT") # TODO remove
    IO.inspect(document)

    # debugging
    Logger.info("#{username} has joined shared document. Users after join: #{inspect(PresenceHelper.list_instances(:username))}.")

    current_text = Cognitus.Document.update_text_from_document(document)
    Logger.debug("Sending current document text to new user: #{inspect(current_text)}")

    # Assign the document to the socket and send the initial peer list and current username to the client
    socket =
      socket
      |> assign(:users, users)
      |> assign(:username, username)
      |> assign(:document, document)
      |> assign(:editing_title, false)
      |> assign(:title, Cognitus.DocumentTitleAgent.get_title())
      |> assign(:text, current_text)
    {:ok, socket}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: %{joins: _joins, leaves: _leaves}}, socket) do
    # Fetch the updated list of users from Presence
    users = Presence.list("peers")

    {:noreply, assign(socket, :users, users)}
  end

  #########################################################################
  ######################### RENDER BROWSER'S VIEW #########################
  #########################################################################

  # Automatically render template cognitus_web/live/document_live.html.heex

  #########################################################################
  ############################# HANDLE EVENTS #############################
  #########################################################################
  # -------------------------- DOCUMENT'S TITLE --------------------------
  # Handling event "Enter document's title edition mode"
  def handle_event("edit_title", _params, socket) do
    Logger.info("#{socket.assigns[:username]} has entered in title edition mode.")
    {:noreply, assign(socket, editing_title: true)}
  end

  # Handling event "Save a new document's title"
  def handle_event("save_title", %{"title" => new_title}, socket) do
    Cognitus.DocumentTitleAgent.set_title(new_title)
    # Broadcast the new title to all of the connected clients
    Phoenix.PubSub.broadcast(
      Cognitus.PubSub,
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

  # ------------------------- DOCUMENT'S UPDATE -------------------------
  # Handling event "insertion of a character"
  @impl true
  def handle_event("insert_character", %{"ch_value" => ch_value, "position" => position}, socket) do
    current_peer_id = socket.id
    document = socket.assigns[:document]
    Cognitus.Document.insert(document, position, current_peer_id, ch_value)

    updated_text = Cognitus.Document.update_text_from_document(document)
#    Phoenix.PubSub.broadcast(                      # TODO verify if necessary, else remove (should go through Delta CRDT)
#      Cognitus.PubSub,
#      "document_updates",
#      %{event: "text_updated", text: updated_text}
#    )

    Logger.info("#{socket.assigns[:username]} has inserted character #{ch_value} at position #{position}.")
    Logger.debug("Document state of #{socket.assigns[:username]} after insertion operation: #{updated_text}")
    {:noreply, assign(socket, :text, updated_text)}
  end

  @impl true
  def handle_event("delete_character", %{"position" => position}, socket) do
    document = socket.assigns[:document]
    ch_value = Cognitus.Document.delete(document, position)
    updated_text = Cognitus.Document.update_text_from_document(document)

#    Phoenix.PubSub.broadcast(                                               # TODO verify if necessary, else remove (should go through Delta CRDT)
#      Cognitus.PubSub,
#      "document_updates",
#      %{event: "text_updated", text: updated_text}
#    )
    Logger.info("#{socket.assigns[:username]} has deleted character #{ch_value} at position #{position}.")
    Logger.debug("Document state of #{socket.assigns[:username]} after deletion operation: #{updated_text}")

    {:noreply, assign(socket, :text, updated_text)}
  end

#  @impl true
#  def handle_info(%{event: "text_updated", text: updated_text}, socket) do  # TODO verify if necessary, else remove (should go through Delta CRDT)
#    Logger.debug("Received updated text: #{updated_text}")
#
#    {:noreply, assign(socket, :text, updated_text)}
#  end

end
