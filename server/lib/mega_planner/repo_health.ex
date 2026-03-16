defmodule MegaPlanner.RepoHealth do
  @moduledoc false

  alias MegaPlanner.Repo

  def write_access do
    Repo.checkout(fn ->
      case Repo.query("BEGIN IMMEDIATE") do
        {:ok, _result} ->
          case Repo.query("ROLLBACK") do
            {:ok, _rollback_result} -> :ok
            {:error, reason} -> {:error, Exception.message(reason)}
          end

        {:error, reason} ->
          {:error, Exception.message(reason)}
      end
    end)
  rescue
    error -> {:error, Exception.message(error)}
  end
end
