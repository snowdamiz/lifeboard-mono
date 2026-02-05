defmodule MegaPlanner.Receipts.MockReceiptParser do
  @moduledoc """
  Mock receipt parser for testing. Provides deterministic responses without calling external APIs.
  
  Includes fixtures with intentionally scrambled text to simulate:
  - OCR errors (misread characters)
  - Partial data (missing fields)
  - Completely unreadable sections
  - Edge cases (multi-quantity items, returns, coupons)
  """

  require Logger

  @doc """
  Parse a "receipt" without calling any external API.
  
  ## Options
  - `:fixture` - Which fixture to return (default: :partial_scramble)
    - `:clean` - Perfect OCR, all fields present
    - `:partial_scramble` - Some OCR errors, some missing fields
    - `:heavy_scramble` - Many OCR errors, lots of missing data
    - `:garbage` - Mostly unreadable
    - `:costco` - Costco-specific format with abbreviations
    - `:walmart` - Walmart format with tax codes
  - `:household_id` - Passed through because real parser uses it
  """
  def parse_receipt(_image_data, household_id, opts \\ []) do
    fixture = Keyword.get(opts, :fixture, :partial_scramble)
    
    Logger.info("[MockReceiptParser] Using fixture: #{fixture}")
    
    data = get_fixture(fixture)
    |> maybe_enrich_with_household(household_id)
    
    {:ok, data}
  end

  # ============================================
  # FIXTURES
  # ============================================

  defp get_fixture(:clean) do
    %{
      store: %{
        name: "Walmart Supercenter",
        store_id: "2341",
        address: "123 Main Street, Anytown, MI 48101",
        phone: "(555) 123-4567"
      },
      summary: %{
        subtotal: "45.98",
        tax: "3.79",
        total: "49.77",
        tax_rate: "0.0825",
        payment_method: "VISA ****1234",
        date: "2026-02-04",
        time: "14:32:15"
      },
      items: [
        %{
          raw_text: "ORGANIC MILK 1GAL",
          brand: "Horizon Organic",
          item: "Milk",
          quantity: 1,
          unit: "gallon",
          unit_price: "6.99",
          total_price: "6.99",
          taxable: false,
          tax_indicator: "N",
          store_code: "001234567890"
        },
        %{
          raw_text: "GV WHITE BREAD",
          brand: "Great Value",
          item: "Bread",
          quantity: 1,
          unit: "loaf",
          unit_price: "1.50",
          total_price: "1.50",
          taxable: false,
          tax_indicator: "N",
          store_code: "001234567891"
        },
        %{
          raw_text: "TIDE PODS 42CT",
          brand: "Tide",
          item: "Laundry Detergent Pods",
          quantity: 1,
          unit: "box",
          unit_price: "19.99",
          total_price: "19.99",
          taxable: true,
          tax_indicator: "X",
          tax_rate: "0.0825",
          store_code: "037000509783"
        }
      ]
    }
  end

  defp get_fixture(:partial_scramble) do
    %{
      store: %{
        name: "W@LM*RT Superc3nter",  # OCR errors in name
        store_id: "234l",              # 'l' instead of '1'
        address: "123 Main Str33t, Anytown, MI 48l01",  # Some errors
        phone: nil                     # Missing
      },
      summary: %{
        subtotal: "45.9B",            # 'B' instead of '8'
        tax: "3.79",
        total: "49.7?",               # Uncertain digit
        tax_rate: nil,                # Missing
        payment_method: "VISA ****12",  # Truncated
        date: "2026-02-O4",           # 'O' instead of '0'
        time: nil
      },
      items: [
        %{
          raw_text: "ORG MLK 1GL",      # Heavily abbreviated
          brand: nil,                    # Couldn't detect
          item: "Milk",
          quantity: 1,
          unit: "gallon",
          unit_price: "6.99",
          total_price: "6.99",
          taxable: false,
          tax_indicator: "N",
          store_code: "0012345678g0"    # 'g' instead of '9'
        },
        %{
          raw_text: "GV WH1TE BR3AD",   # '1' and '3' instead of 'I' and 'E'
          brand: "Great Value",
          item: nil,                     # Couldn't parse
          quantity: 1,
          unit: nil,
          unit_price: "l.50",           # 'l' instead of '1'
          total_price: "1.50",
          taxable: false,
          tax_indicator: "N",
          store_code: nil
        },
        %{
          raw_text: "T1D3 P0DS 42CT",   # Multiple OCR errors
          brand: nil,
          item: "Pods",
          quantity: nil,                 # Couldn't parse count
          unit: "box",
          unit_price: "19.g9",          # 'g' instead of '9'
          total_price: "19.99",
          taxable: true,
          tax_indicator: "X",
          tax_rate: "0.0825",
          store_code: "03700050??83"    # Unknown digits
        },
        %{
          raw_text: "##@!$%^&*()",       # Complete garbage line
          brand: nil,
          item: nil,
          quantity: nil,
          unit: nil,
          unit_price: nil,
          total_price: nil,
          taxable: nil,
          tax_indicator: nil,
          store_code: nil
        }
      ]
    }
  end

  defp get_fixture(:heavy_scramble) do
    %{
      store: %{
        name: "W@|_M*R7",              # Very corrupted
        store_id: nil,
        address: nil,
        phone: nil
      },
      summary: %{
        subtotal: "4?.9?",
        tax: "?.??",
        total: "??.??",
        tax_rate: nil,
        payment_method: nil,
        date: nil,
        time: nil
      },
      items: [
        %{
          raw_text: "0RG M|K 1G|_",
          brand: nil,
          item: nil,
          quantity: nil,
          unit: nil,
          unit_price: "?.??",
          total_price: "6.??",
          taxable: nil,
          tax_indicator: nil,
          store_code: nil
        },
        %{
          raw_text: "!@#$%^&*()_+",
          brand: nil,
          item: nil,
          quantity: nil,
          unit: nil,
          unit_price: nil,
          total_price: "?.??",
          taxable: nil,
          tax_indicator: nil,
          store_code: nil
        }
      ]
    }
  end

  defp get_fixture(:garbage) do
    %{
      store: %{
        name: "!@#$%^&*()",
        store_id: nil,
        address: nil,
        phone: nil
      },
      summary: %{
        subtotal: nil,
        tax: nil,
        total: nil,
        tax_rate: nil,
        payment_method: nil,
        date: nil,
        time: nil
      },
      items: [
        %{
          raw_text: "█████████████",
          brand: nil,
          item: nil,
          quantity: nil,
          unit: nil,
          unit_price: nil,
          total_price: nil,
          taxable: nil,
          tax_indicator: nil,
          store_code: nil
        }
      ]
    }
  end

  defp get_fixture(:costco) do
    %{
      store: %{
        name: "COSTCO WHOLESALE",
        store_id: "4523",
        address: "456 Warehouse Blvd, Big City, CA 90210",
        phone: nil
      },
      summary: %{
        subtotal: "127.45",
        tax: "7.65",
        total: "135.10",
        tax_rate: "0.06",
        payment_method: "VISA",
        date: "2026-02-04",
        time: "10:15"
      },
      items: [
        %{
          raw_text: "KS ORG XVOO 2L",  # Kirkland Signature abbreviation
          brand: nil,                    # Needs learning: KS = Kirkland Signature
          item: "XVOO 2L",               # Needs learning: XVOO = Extra Virgin Olive Oil
          quantity: 1,
          unit: "bottle",
          unit_price: "14.99",
          total_price: "14.99",
          taxable: false,
          tax_indicator: nil,
          store_code: "1234567"
        },
        %{
          raw_text: "KS CKN BRST 6LB",  # Chicken Breast abbreviation
          brand: nil,
          item: "CKN BRST",
          quantity: 1,
          unit: "package",
          unit_price: "24.99",
          total_price: "24.99",
          taxable: false,
          tax_indicator: nil,
          store_code: "2345678"
        },
        %{
          raw_text: "DYSON V15 DETECT A",  # Taxable item
          brand: "Dyson",
          item: "V15 Vacuum",
          quantity: 1,
          unit: "each",
          unit_price: "599.99",
          total_price: "599.99",
          taxable: true,
          tax_indicator: "A",
          tax_rate: "0.06",
          store_code: "3456789"
        }
      ]
    }
  end

  defp get_fixture(:walmart) do
    %{
      store: %{
        name: "WALMART SUPERCENTER",
        store_id: "02010",
        address: "789 Retail Drive, Shoptown, TX 75001",
        phone: "(555) 987-6543"
      },
      summary: %{
        subtotal: "52.43",
        tax: "2.67",
        total: "55.10",
        tax_rate: "0.0825",
        payment_method: "DEBIT",
        date: "2026-02-04",
        time: "16:45:22"
      },
      items: [
        %{
          raw_text: "STRAWBERRIES 1LB",
          brand: nil,
          item: "Strawberries",
          quantity: 1,
          unit: "lb",
          unit_price: "6.34",
          total_price: "6.34",
          taxable: false,
          tax_indicator: "N",
          store_code: "812049005200"
        },
        %{
          raw_text: "GV 2% MILK GAL",
          brand: "Great Value",
          item: "2% Milk",
          quantity: 1,
          unit: "gallon",
          unit_price: "3.78",
          total_price: "3.78",
          taxable: false,
          tax_indicator: "F",  # Food stamp eligible
          store_code: "078742127705"
        },
        %{
          raw_text: "GAS CAN 5GAL",
          brand: nil,
          item: "Gas Can",
          quantity: 1,
          unit: "each",
          unit_price: "34.88",
          total_price: "34.88",
          taxable: true,
          tax_indicator: "X",
          tax_rate: "0.0825",
          store_code: "759176034500"
        }
      ]
    }
  end

  # Default fallback
  defp get_fixture(_unknown), do: get_fixture(:partial_scramble)

  # ============================================
  # HELPERS
  # ============================================

  defp maybe_enrich_with_household(data, _household_id) do
    # In a real implementation, this would look up format corrections
    # For mock, we just pass through
    data
  end
end
