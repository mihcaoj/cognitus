defmodule Cognitus.DocumentTitleAgent do
  use Agent

  @default_title "Untitled Document"

  # Start the agent with a default title
  def start_link(_) do
    Agent.start_link(fn -> @default_title end, name: __MODULE__)
  end

  # Get the current title
  def get_title do
    Agent.get(__MODULE__, & &1)
  end

  # Set a new title
  def set_title(new_title) do
    Agent.update(__MODULE__, fn _ -> new_title end)
  end
end