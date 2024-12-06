defmodule Cognitus.ETS_helper do
  @moduledoc """
  Helper functions for ETS tables
  """

  @spec list_instances(:ets.tid()) :: [term()]
  @doc """
  Retrieve all instances of an ETS table as a list, where the ETS table stores each item in a tuple {instance}
  """
  def list_instances(ets_table) do
    for {id, _meta} <- :ets.tab2list(ets_table), is_binary(id), do: id
  end
end
