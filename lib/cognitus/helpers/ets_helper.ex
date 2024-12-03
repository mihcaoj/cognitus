defmodule Cognitus.ETS_helper do
  @moduledoc """
  Helper functions for ETS tables
  """

  @spec list_instances(:ets.tid()) :: [term()]
  @doc """
  Retrieve all instances of an ETS table as a list, where the ETS table stores each item in a tuple {instance}
  """
  def list_instances(ets_table) do
    :ets.tab2list(ets_table) |> Enum.map(fn {item} -> item end)
  end
end
