Application.ensure_all_started(:telemetry)
Application.ensure_all_started(:decimal)
Application.ensure_all_started(:jason)
Application.ensure_all_started(:db_connection)
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)
Application.ensure_all_started(:ecto_sql)

{:ok, _} = MegaPlanner.Repo.start_link()

alias MegaPlanner.Repo
alias MegaPlanner.Receipts.Purchase
import Ecto.Query

# Check for Brand3 specifically
IO.puts("\n--- Checking for Brand3 ---")
purchases = from(p in Purchase, where: ilike(p.brand, "Brand3"), order_by: [desc: p.inserted_at])
|> Repo.all()

if Enum.empty?(purchases) do
  IO.puts("No purchases found for Brand3")
else
  Enum.each(purchases, fn p ->
    IO.puts("ID: #{p.id}, Brand: #{p.brand}, StoreCode: #{inspect(p.store_code)}, ItemName: #{inspect(p.item_name)}")
  end)
end

# Check for ANY purchase with StoreCode
IO.puts("\n--- Checking for ANY purchase with Store Code ---")
any_code = from(p in Purchase, where: not is_nil(p.store_code), limit: 5) |> Repo.all()
Enum.each(any_code, fn p ->
    IO.puts("Brand: #{p.brand}, StoreCode: #{inspect(p.store_code)}")
end)
