defmodule CognitusWeb.UsernameService do
  @moduledoc """
  Service handling username generation and associated color.
  """
  @type username :: String.t()
  @type username_color :: String.t()

  # List of famous computer scientist names
  @all_usernames [
    "Alan Turing", "Donald Knuth", "Tim Berners-Lee", "John McCarthy",
    "Edsger Dijkstra", "Grace Hopper", "Claude Shannon", "Linus Torvalds",
    "John von Neumann", "Barbara Liskov", "Bjarne Stroustrup", "Guido van Rossum",
    "Vint Cerf", "Dennis Ritchie", "Ken Thompson", "Alan Kay", "Marvin Minsky",
    "Niklaus Wirth", "Andrew Tanenbaum", "Douglas Engelbart", "Ada Lovelace",
    "Margaret Hamilton", "Leslie Lamport", "Stephen Wolfram", "James Gosling",
    "Betty Holberton", "Adele Goldberg", "Larry Page", "Bill Gates"
  ]

  @spec generate_username() :: {username(), username_color()}
  @doc """
  Generate a username from a list of famous computer scientist names.
  """
  def generate_username() do
    # 1. Retrieve the list of usernames currently in use using Presence
    #   - Enum.flat_map iterates through this map and extracts all usernames from the metas list for each user
    #   - The comprehension loop extracts the username key from each metadata map
    #   - do: username collects all extracted usernames in a flat list
    assigned_usernames =
      CognitusWeb.Presence.list("editor:lobby")
      |> Enum.flat_map(fn {_id, %{metas: metas}} -> for %{username: username} <- metas, do: username end)

    # 2. Calculate available usernames
    available_usernames = all_usernames -- assigned_usernames

    # 3. Assign a username and a color
    #   - If list is empty return an error message
    #   - Otherwise take the head of the list and assign it
    case available_usernames do
      [] -> Logger.error("No usernames available!")
            {:error, "No usernames available"}

      [first_username | _rest] -> {first_username, generate_username_color()}
    end
  end

  #########################################################################
  ######################### HELPER FUNCTIONS  #############################
  #########################################################################
  @spec all_usernames() :: [username()]
  defp all_usernames, do: @all_usernames

  @spec generate_username_color() :: username_color()
  # Helper function to generate a unique color for the user's username
  defp generate_username_color() do
    adjust = fn -> Enum.random(1..255) end

    # generate RGB values in the adjusted range
    r = adjust.()
    g = adjust.()
    b = adjust.()

    # return the generated color in RGB format
    "rgb(#{r}, #{g}, #{b})"
  end
end
