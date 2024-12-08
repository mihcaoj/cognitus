defmodule Cognitus.PresenceHelper do
  @moduledoc """
  Helper functions for `Presence` module
  """
  alias CognitusWeb.Presence

  @spec list_instances(atom()) :: [term()]
  @doc """
  Retrieve all instances of something stored in `Presence` (usernames, documents, etc).
  """
  def list_instances(instance_type) do
    Presence.list("peers")
    |> Enum.flat_map(fn {_key, %{metas: metas}} ->
              Enum.map(metas, fn meta -> Map.get(meta, instance_type) end)
      end)
    end
end