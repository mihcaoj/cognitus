defmodule CognitusWeb.UsernameService do
  require Logger
  @moduledoc """
  Service handling username generation and associated color.
  """
  alias Cognitus.PresenceHelper
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
    # Retrieve assigned usernames from Presence and calculate available ones
    assigned_usernames = PresenceHelper.list_instances(:username)
    available_usernames = all_usernames() -- assigned_usernames

    # Assign a username and a color
    #   - If list is empty return an error message
    #   - Otherwise take the head of the list and assign it
    case available_usernames do
      [] -> Logger.error("No usernames available!")
            {:error, "No usernames available"}

      usernames_list -> {Enum.random(usernames_list), generate_username_color()}
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
    "rgb(#{Enum.random(20..200)}, #{Enum.random(20..200)}, #{Enum.random(20..200)})"
  end
end
