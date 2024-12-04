defmodule CognitusWeb.Presence do
@moduledoc """
Module to manage the Presence.
"""
  use Phoenix.Presence,
    otp_app: :cognitus,
    pubsub_server: Cognitus.PubSub
end
