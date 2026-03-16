defmodule MegaPlanner.ChangesetConstraints do
  @moduledoc false

  import Ecto.Changeset

  def sqlite_compatible_unique_constraint(changeset, fields, opts) do
    normalized_fields = List.wrap(fields)

    changeset =
      unique_constraint(changeset, normalized_fields, opts)

    case Keyword.fetch(opts, :name) do
      {:ok, configured_name} ->
        sqlite_name = sqlite_unique_index_name(changeset, normalized_fields)

        if to_string(configured_name) == sqlite_name do
          changeset
        else
          unique_constraint(
            changeset,
            normalized_fields,
            Keyword.put(opts, :name, String.to_atom(sqlite_name))
          )
        end

      :error ->
        changeset
    end
  end

  defp sqlite_unique_index_name(changeset, fields) do
    source = changeset.data.__struct__.__schema__(:source)
    "#{source}_#{Enum.map_join(fields, "_", &to_string/1)}_index"
  end
end
