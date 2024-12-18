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
  alias Cognitus.Repo
  alias Cognitus.DocumentSchema
  import Ecto.Query

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

    # Fetch the first document from the database or create a new one if none exists
    # Using Repo.one with a limit of 1 since we currently support only one document
    db_document = case Repo.one(from d in DocumentSchema, limit: 1) do
      nil ->
        # No document exists - create default one with default values
        %DocumentSchema{
          title: "Untitled Document",
          content: "",
        } |> Repo.insert!()

      doc -> doc # if a document is found, return it
    end

    if connected?(socket) do
      # Subscribe to PubSub for title, users, document and caret updates
      topics = ["title_updates", "users", "document_updates", "caret_updates"]
      Enum.map(topics, fn topic -> Phoenix.PubSub.subscribe(PubSub, topic) end)

      # Debugging TODO: REMOVE - Séverine: pas sûre qu'il faille enlever ça reste du debugging
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
    Logger.info("#{username} has joined shared document. Users after join: #{inspect(PresenceHelper.list_instances(:username))}.")

    current_text = Document.update_text_from_document(document)

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
      |> assign(:db_document, db_document)
      |> assign(:editing_title, false)
      #|> assign(:title, DocumentTitleAgent.get_title())
      #|> assign(:text, current_text)
      |> assign(:title, db_document.title)
      |> assign(:text, db_document.content || "")
      |> assign(:caret_positions, %{})
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

    # Save title to database
    socket.assigns.db_document
    |> DocumentSchema.changeset(%{title: new_title})
    |> Repo.update()

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

    # Save changes to database
    socket.assigns.db_document
    |> DocumentSchema.changeset(%{content: updated_text})
    |> Repo.update()

    # Broadcast the update to all of the LiveView processes
    Phoenix.PubSub.broadcast(
      PubSub,
      "document_updates",
      %{event: "text_updated", text: updated_text}
    )

    Logger.info("#{socket.assigns[:username]} has inserted character #{ch_value} at position #{position}.")

    # Update this LiveView process's state with the updated text
    {:noreply, assign(socket, :text, updated_text)}
  end

  # Handling event "deletion of a character"
  @impl true
  def handle_event("delete_character", %{"position_start" => position_start, "position_end" => position_end}, socket) do
    document = socket.assigns[:document]
    if position_start == position_end do
      {document, ch_value} = Document.delete(document, position_start-1)
      Logger.info("#{socket.assigns[:username]} has deleted character #{ch_value} at position #{position_start-1}.")
    else
      interval_end = position_end - 1
      positions_to_delete = interval_end..position_start
      IO.inspect(positions_to_delete)
      {document, deleted_characters} =
        Enum.reduce(positions_to_delete, {document, []}, fn position, {acc_doc, acc_ch} ->
          {new_doc, ch_value} = Document.delete(acc_doc, position)
          {new_doc, [ch_value | acc_ch]} # Accumulate the deleted characters and use last document
        end) # Reverse the order of accumulated deleted characters
      Logger.info("#{socket.assigns[:username]} has deleted characters #{inspect(deleted_characters)} between positions #{position_start} and #{interval_end}.")
    end

    updated_text = Document.update_text_from_document(document)

    # Save changes to database
    socket.assigns.db_document
    |> DocumentSchema.changeset(%{content: updated_text})
    |> Repo.update()

    # Broadcast the update to all of the LiveView processes
    Phoenix.PubSub.broadcast(
      PubSub,
      "document_updates",
      %{event: "text_updated", text: updated_text}
    )

    # Update this LiveView process's state with the updated text
    {:noreply, assign(socket, :text, updated_text)}
  end

  # Handling info for "text updates"
  # This gets called in all of the LiveView processes when they receive the PubSub broadcast
  @impl true
  def handle_info(%{event: "text_updated", text: updated_text}, socket) do
    # Update the LiveView process's socket assigns with the updated text
    socket = assign(socket, :text, updated_text)
    # Push the text update to the client connected to this LiveView process
    # Without this, the UI wouldn't update in real-time for other users
    # Even though the CRDT syncs server state, we need this to sync the UI
    {:noreply, push_event(socket, "text_updated", %{text: updated_text})}
  end

  # -------------------------- CARET UPDATES --------------------------
  # Handling event for updating caret position
  @impl true
  def handle_event("update_caret", %{"position" => position}, socket) do
    username = socket.assigns.username
    color = get_user_color(socket)

    # Broadcast caret position to all clients
    Phoenix.PubSub.broadcast(
      PubSub,
      "caret_updates",
      %{
        event: "caret_updated",
        username: username,
        position: position,
        color: color
      }
    )

    # Update local state
    new_positions = Map.put(socket.assigns.caret_positions, username,
    %{
      position: position,
      color: color
    })

    {:noreply, assign(socket, :caret_positions, new_positions)}
  end

  # Handling info for "caret updates"
  @impl true
  def handle_info(%{event: "caret_updated", username: username, position: position, color: color}, socket) do
    new_positions = Map.put(socket.assigns.caret_positions, username,
    %{
      position: position,
      color: color
    })

    # Broadcast positions to the client
    positions = Enum.map(new_positions, fn {username, data} ->
      %{
        username: username,
        position: data.position,
        color: data.color
      }
    end)

    {:noreply, push_event(socket, "caret_positions", %{positions: positions})}
  end

  # Helper function to get user color
  defp get_user_color(socket) do
    case Enum.find(socket.assigns.users, fn {_id, %{metas: metas}} ->
      Enum.find(metas, &(&1.username == socket.assigns.username))
    end) do
      {_id, %{metas: [meta | _]}} -> meta.color
      _ -> "#000000" # Default color if not found
    end
  end

end
