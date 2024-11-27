# Module to manage the Presence logic

defmodule CognitusWeb.Presence do
  use Phoenix.Presence,
    otp_app: :cognitus,
    pubsub_server: Cognitus.PubSub
end

# TODO A déplacer dans un autre module, non ?