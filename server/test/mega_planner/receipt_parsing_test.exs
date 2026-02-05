defmodule MegaPlanner.ReceiptParsingTest do
  @moduledoc """
  Tests receipt parsing with mock fixtures - NO external API calls.
  
  Tests various OCR quality levels:
  - Clean: Perfect data
  - Partial scramble: Some errors (realistic)
  - Heavy scramble: Many errors
  - Garbage: Mostly unreadable
  - Store-specific: Costco, Walmart patterns
  """
  use ExUnit.Case, async: true
  alias MegaPlanner.{Repo, Accounts}
  alias MegaPlanner.Receipts.MockReceiptParser

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, household} = Accounts.create_household(%{"name" => "ReceiptTest"})
    %{household: household}
  end

  # ============================================
  # CLEAN FIXTURE TESTS (Perfect OCR)
  # ============================================
  describe "Clean receipt parsing" do
    test "extracts all store fields correctly", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :clean)
      
      assert data.store.name == "Walmart Supercenter"
      assert data.store.store_id == "2341"
      assert data.store.address =~ "Main Street"
      assert data.store.phone =~ "555"
    end
    
    test "extracts summary with all fields", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :clean)
      
      assert data.summary.subtotal == "45.98"
      assert data.summary.tax == "3.79"
      assert data.summary.total == "49.77"
      assert data.summary.tax_rate == "0.0825"
      assert data.summary.payment_method =~ "VISA"
    end
    
    test "extracts items with full details", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :clean)
      
      assert length(data.items) == 3
      
      [milk, bread, tide] = data.items
      
      # Milk
      assert milk.raw_text =~ "ORGANIC MILK"
      assert milk.brand == "Horizon Organic"
      assert milk.item == "Milk"
      assert milk.taxable == false
      
      # Tide (taxable)
      assert tide.brand == "Tide"
      assert tide.taxable == true
      assert tide.tax_rate == "0.0825"
    end
  end

  # ============================================
  # PARTIAL SCRAMBLE TESTS (Realistic OCR errors)
  # ============================================
  describe "Partial scramble parsing" do
    test "handles store name OCR errors", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :partial_scramble)
      
      # Store name has errors but is still present
      assert data.store.name != nil
      assert data.store.name =~ ~r/W.*M.*R/i  # Contains W...M...R (Walmart pattern)
    end
    
    test "handles missing fields gracefully", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :partial_scramble)
      
      # Some fields are nil
      assert data.store.phone == nil
      assert data.summary.tax_rate == nil
    end
    
    test "items with nil fields are still present", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :partial_scramble)
      
      # Should have garbage item at end
      garbage_item = List.last(data.items)
      assert garbage_item.raw_text =~ ~r/[#@!$%]/
      assert garbage_item.item == nil
      assert garbage_item.total_price == nil
    end
    
    test "uncertain digits marked with ?", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :partial_scramble)
      
      # Total has uncertain digit
      assert data.summary.total =~ "?"
    end
  end

  # ============================================
  # HEAVY SCRAMBLE TESTS (Many OCR errors)
  # ============================================
  describe "Heavy scramble parsing" do
    test "most fields are nil or contain ?", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :heavy_scramble)
      
      assert data.summary.subtotal =~ "?"
      assert data.summary.tax =~ "?"
      assert data.summary.total =~ "?"
      assert data.store.store_id == nil
    end
  end

  # ============================================
  # GARBAGE TESTS (Unreadable)
  # ============================================
  describe "Garbage receipt parsing" do
    test "returns data structure even for unreadable receipt", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :garbage)
      
      # Structure exists but no usable data
      assert data.store.name != nil  # Has garbage value
      assert data.summary.total == nil
      assert length(data.items) == 1
    end
  end

  # ============================================
  # STORE-SPECIFIC TESTS
  # ============================================
  describe "Costco receipt parsing" do
    test "handles Kirkland Signature abbreviations", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :costco)
      
      ks_item = Enum.find(data.items, &(&1.raw_text =~ "KS"))
      assert ks_item != nil
      assert ks_item.raw_text =~ "KS ORG XVOO"
      # Brand is nil because learning hasn't happened yet
      assert ks_item.brand == nil
    end
    
    test "has Costco-specific tax indicators", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :costco)
      
      taxable_item = Enum.find(data.items, &(&1.taxable == true))
      assert taxable_item.tax_indicator == "A"  # Costco uses A for taxable
    end
  end

  describe "Walmart receipt parsing" do
    test "handles Great Value abbreviations", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :walmart)
      
      gv_item = Enum.find(data.items, &(&1.raw_text =~ "GV"))
      assert gv_item != nil
      assert gv_item.brand == "Great Value"
    end
    
    test "has Walmart-specific tax codes", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :walmart)
      
      # N = not taxable, X = taxable, F = food stamp eligible
      assert Enum.any?(data.items, &(&1.tax_indicator == "N"))
      assert Enum.any?(data.items, &(&1.tax_indicator == "X"))
      assert Enum.any?(data.items, &(&1.tax_indicator == "F"))
    end
    
    test "extracts store code (ST#)", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :walmart)
      
      assert data.store.store_id == "02010"
    end
  end

  # ============================================
  # ROUND-TRIP: Parse → Create → Load → Verify
  # ============================================
  describe "Receipt parsing round-trip" do
    alias MegaPlanner.Receipts
    
    test "parsed data can be saved as purchases and reloaded", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :clean)
      
      # Create trip and stop
      {:ok, trip} = Receipts.create_trip(ctx.household.id, %{
        "trip_start" => "2026-02-04T10:00:00Z"
      })
      
      {:ok, stop} = Receipts.create_stop(trip.id, %{
        "store_name" => data.store.name,
        "subtotal" => data.summary.subtotal,
        "tax_total" => data.summary.tax,
        "receipt_total" => data.summary.total
      })
      
      # Create purchases from parsed items
      created_purchases = Enum.map(data.items, fn item ->
        {:ok, purchase} = Receipts.create_purchase(%{
          "stop_id" => stop.id,
          "receipt_item" => item.raw_text,
          "brand" => item.brand,
          "item" => item.item,
          "count" => to_string(item.quantity || 1),
          "price_per_count" => item.unit_price,
          "total_price" => item.total_price,
          "taxable" => item.taxable || false,
          "date" => "2026-02-04"
        })
        purchase
      end)
      
      assert length(created_purchases) == 3
      
      # RELOAD and verify
      trip_reloaded = Receipts.get_trip(trip.id)
      stop_reloaded = hd(trip_reloaded.stops)
      
      assert stop_reloaded.store_name == "Walmart Supercenter"
      assert length(stop_reloaded.purchases) == 3
      
      # Find the milk purchase and verify fields
      milk = Enum.find(stop_reloaded.purchases, &(&1.receipt_item =~ "MILK"))
      assert milk.brand == "Horizon Organic"
      assert milk.item == "Milk"
      assert Decimal.compare(milk.total_price, Decimal.new("6.99")) == :eq
    end
    
    test "partial scramble data saves with nil fields", ctx do
      {:ok, data} = MockReceiptParser.parse_receipt("fake_image", ctx.household.id, fixture: :partial_scramble)
      
      # Filter out garbage items (no total_price)
      valid_items = Enum.filter(data.items, &(&1.total_price != nil))
      
      {:ok, trip} = Receipts.create_trip(ctx.household.id, %{"trip_start" => "2026-02-04T10:00:00Z"})
      {:ok, stop} = Receipts.create_stop(trip.id, %{"store_name" => data.store.name})
      
      # Create purchases only for items with prices
      Enum.each(valid_items, fn item ->
        Receipts.create_purchase(%{
          "stop_id" => stop.id,
          "receipt_item" => item.raw_text,
          "brand" => item.brand,  # May be nil
          "item" => item.item,    # May be nil
          "total_price" => item.total_price,
          "taxable" => item.taxable || false,
          "date" => "2026-02-04"
        })
      end)
      
      # Verify we can load even with partial data
      trip_reloaded = Receipts.get_trip(trip.id)
      assert trip_reloaded != nil
      assert length(hd(trip_reloaded.stops).purchases) == length(valid_items)
    end
  end
end
