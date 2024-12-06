defmodule Cognitus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Create the ETS tables for peers and their document replica
    :ets.new(:peers, [:named_table, :public, :set, read_concurrency: true])
    :ets.new(:documents, [:named_table, :public, :set, read_concurrency: true])

    children = [
      CognitusWeb.Telemetry,
      Cognitus.Repo,
      {DNSCluster, query: Application.get_env(:cognitus, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Cognitus.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Cognitus.Finch},
      # Start a worker by calling: Cognitus.Worker.start_link(arg)
      # {Cognitus.Worker, arg},
      # Start to serve requests, typically the last entry
      CognitusWeb.Endpoint,
      CognitusWeb.Presence,
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cognitus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CognitusWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
