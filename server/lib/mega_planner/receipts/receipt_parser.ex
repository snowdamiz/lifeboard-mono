defmodule MegaPlanner.Receipts.ReceiptParser do
  @moduledoc """
  Service for parsing receipt images using OpenRouter API with ByteDance Seed model.
  Extracts structured data from receipt images including store info,
  line items, and transaction details.
  """

  require Logger

  @openrouter_api_url "https://openrouter.ai/api/v1/chat/completions"
  @model "bytedance-seed/seed-1.6-flash"

  @doc """
  Parses a receipt image and returns structured data.
  
  ## Parameters
    - image_data: Base64 encoded image data (with or without data URL prefix)
    - household_id: The household ID for matching existing stores/brands
    
  ## Returns
    - {:ok, %{store: ..., transaction: ..., items: ...}} on success
    - {:error, reason} on failure
  """
  def parse_receipt_image(image_data, household_id) do
    try do
      with {:ok, api_key} <- get_api_key(),
           {:ok, clean_image} <- clean_image_data(image_data),
           {:ok, response} <- call_openrouter_api(api_key, clean_image),
           {:ok, parsed} <- parse_api_response(response) do
        enrich_with_matches(parsed, household_id)
      end
    rescue
      e ->
        Logger.error("Exception during receipt parsing: #{inspect(e)}")
        {:error, "An unexpected error occurred while parsing the receipt"}
    end
  end

  defp get_api_key do
    case System.get_env("OPENROUTER_API_KEY") do
      nil -> {:error, "OPENROUTER_API_KEY environment variable not set"}
      key -> {:ok, key}
    end
  end

  defp clean_image_data(image_data) do
    # Remove data URL prefix if present
    clean = 
      image_data
      |> String.replace(~r/^data:image\/[^;]+;base64,/, "")
      |> String.trim()
    
    {:ok, clean}
  end

  defp call_openrouter_api(api_key, image_base64, retry_count \\ 0) do
    # Detect mime type from base64 header or default to jpeg
    mime_type = detect_mime_type(image_base64)
    data_url = "data:#{mime_type};base64,#{image_base64}"
    
    body = %{
      model: @model,
      messages: [
        %{
          role: "user",
          content: [
            %{
              type: "text",
              text: build_extraction_prompt()
            },
            %{
              type: "image_url",
              image_url: %{
                url: data_url
              }
            }
          ]
        }
      ],
      temperature: 0.1,
      response_format: %{type: "json_object"}
    }

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"},
      {"HTTP-Referer", "https://lifeboard.app"},
      {"X-Title", "LifeBoard Receipt Scanner"}
    ]

    request = Finch.build(:post, @openrouter_api_url, headers, Jason.encode!(body))

    case Finch.request(request, MegaPlanner.Finch, receive_timeout: 60_000) do
      {:ok, %Finch.Response{status: 200, body: response_body}} ->
        {:ok, response_body}
      
      {:ok, %Finch.Response{status: 429, body: _response_body}} when retry_count < 3 ->
        # Rate limited - wait and retry with exponential backoff
        wait_time = :math.pow(2, retry_count) * 1000 |> round()
        Logger.warning("OpenRouter API rate limited (429), retrying in #{wait_time}ms (attempt #{retry_count + 1}/3)")
        :timer.sleep(wait_time)
        call_openrouter_api(api_key, image_base64, retry_count + 1)
      
      {:ok, %Finch.Response{status: 429, body: response_body}} ->
        Logger.error("OpenRouter API rate limit exceeded after 3 retries: #{response_body}")
        {:error, "Rate limit exceeded. Please wait a moment and try again."}
      
      {:ok, %Finch.Response{status: status, body: response_body}} ->
        Logger.error("OpenRouter API error: #{status} - #{response_body}")
        {:error, "OpenRouter API returned status #{status}"}
      
      {:error, reason} ->
        Logger.error("OpenRouter API request failed: #{inspect(reason)}")
        {:error, "Failed to connect to OpenRouter API: #{inspect(reason)}"}
    end
  end

  defp detect_mime_type(base64_data) do
    # Try to detect image type from base64 data
    cond do
      String.starts_with?(base64_data, "/9j/") -> "image/jpeg"
      String.starts_with?(base64_data, "iVBOR") -> "image/png"
      String.starts_with?(base64_data, "R0lGO") -> "image/gif"
      String.starts_with?(base64_data, "UklGR") -> "image/webp"
      true -> "image/jpeg"  # Default to JPEG
    end
  end

  defp build_extraction_prompt do
    """
    Analyze this receipt image and extract structured data. Return a JSON object with this exact structure:
    
    {
      "store": {
        "name": "Store name from receipt header",
        "address": "Full address if visible",
        "city": "City name",
        "state": "State abbreviation (e.g., TX, CA)",
        "store_code": "Store number if present (e.g., #1234)",
        "phone": "Phone number if visible"
      },
      "transaction": {
        "date": "YYYY-MM-DD format",
        "time": "HH:MM format (24-hour)",
        "subtotal": "Subtotal amount as string (e.g., '25.99')",
        "tax": "Tax amount as string",
        "total": "Total amount as string",
        "payment_method": "Cash, Credit, Debit, etc. if visible"
      },
      "items": [
        {
          "raw_text": "Original line as it appears on receipt",
          "brand": "Brand name if identifiable (e.g., 'Great Value', 'Coca-Cola')",
          "item": "Product name/description",
          "quantity": 1,
          "unit": "Unit of measure if present (oz, lb, ct, ea, etc.)",
          "unit_quantity": "Amount in units (e.g., '16' for 16oz)",
          "unit_price": "Price per unit if shown",
          "total_price": "Line item total as string",
          "taxable": true,
          "tax_amount": "Tax amount for this specific item if shown separately, otherwise null",
          "store_code": "Item SKU/code if visible"
        }
      ]
    }
    
    Rules:
    - Extract as much information as possible from the receipt
    - For items without clear brands, leave brand empty or use store brand name
    - Parse prices as strings to preserve decimal precision
    - Set taxable to true if item has a tax indicator (T, TAX, *)
    - If a field is not visible on the receipt, use null
    - Keep the raw_text for each item as it appears on the receipt
    - IMPORTANT: Convert ALL CAPS text to Proper Title Case for brand and item fields
      - Example: "CHICKEN BREAST" should become "Chicken Breast"
      - Example: "GV WHOLE MILK" should become "Gv Whole Milk" (brand) or "Great Value" if recognizable
      - Keep acronyms like "TV", "DVD", "USB" in uppercase
    - If tax_amount is shown per-item on the receipt, extract it; otherwise use null
    """
  end

  defp parse_api_response(response_body) do
    Logger.info("Parsing OpenRouter API response...")
    
    with {:ok, response} <- Jason.decode(response_body) do
      Logger.info("Response decoded, checking structure...")
      
      case response do
        # OpenAI-compatible format from OpenRouter
        %{"choices" => [%{"message" => %{"content" => json_text}} | _]} ->
          Logger.info("Found content in response, parsing JSON...")
          # The content might be the JSON directly or wrapped in markdown code blocks
          cleaned_json = json_text
            |> String.replace(~r/```json\n?/, "")
            |> String.replace(~r/```\n?/, "")
            |> String.trim()
          
          case Jason.decode(cleaned_json) do
            {:ok, parsed_data} ->
              Logger.info("JSON parsed successfully")
              {:ok, normalize_parsed_data(parsed_data)}
            {:error, decode_error} ->
              Logger.error("Failed to decode extracted JSON: #{inspect(decode_error)}")
              Logger.error("JSON text was: #{String.slice(cleaned_json, 0, 500)}")
              {:error, "Failed to decode receipt JSON from AI"}
          end
        
        %{"error" => error_details} ->
          Logger.error("OpenRouter API returned error: #{inspect(error_details)}")
          {:error, "OpenRouter API error: #{inspect(error_details)}"}
        
        other ->
          Logger.error("Unexpected response structure: #{inspect(other)}")
          {:error, "Unexpected response structure from AI"}
      end
    else
      {:error, decode_error} ->
        Logger.error("Failed to decode API response body: #{inspect(decode_error)}")
        {:error, "Failed to parse API response"}
    end
  end

  defp normalize_parsed_data(data) do
    items = data["items"] || []
    normalized_items = Enum.map(items, &normalize_item/1)
    combined_items = combine_duplicate_items(normalized_items)
    
    %{
      store: normalize_store(data["store"] || %{}),
      transaction: normalize_transaction(data["transaction"] || %{}),
      items: combined_items
    }
  end

  # Combine items with the same brand+item combination, summing quantities and prices
  defp combine_duplicate_items(items) do
    Logger.info("combine_duplicate_items: Starting with #{length(items)} items")
    
    grouped = items
    |> Enum.group_by(fn item -> 
      key = {String.downcase(item.brand || ""), String.downcase(item.item || "")}
      Logger.debug("Item key: #{inspect(key)} for brand=#{item.brand}, item=#{item.item}")
      key
    end)
    
    Logger.info("combine_duplicate_items: Grouped into #{map_size(grouped)} unique brand+item combinations")
    
    result = grouped
    |> Enum.map(fn {key, group} -> 
      Logger.info("Merging group #{inspect(key)} with #{length(group)} items")
      merge_item_group(group) 
    end)
    
    Logger.info("combine_duplicate_items: Returning #{length(result)} combined items")
    result
  end

  defp merge_item_group([single_item]), do: single_item
  defp merge_item_group(items) do
    Logger.info("merge_item_group: Merging #{length(items)} items together")
    # Take the first item as base and combine quantities/prices from others
    base = hd(items)
    
    total_quantity = items
    |> Enum.map(fn item -> 
      qty = item.quantity || 1
      Logger.info("  - Item quantity: #{qty}")
      qty
    end)
    |> Enum.sum()
    
    Logger.info("  Total quantity: #{total_quantity}")
    
    total_price = items
    |> Enum.map(fn item -> 
      case item.total_price do
        nil -> 0
        "" -> 0
        price when is_binary(price) -> 
          case Float.parse(price) do
            {val, _} -> val
            :error -> 0
          end
        price when is_number(price) -> price
      end
    end)
    |> Enum.sum()
    
    total_tax = items
    |> Enum.map(fn item -> 
      case item.tax_amount do
        nil -> 0
        "" -> 0
        tax when is_binary(tax) -> 
          case Float.parse(tax) do
            {val, _} -> val
            :error -> 0
          end
        tax when is_number(tax) -> tax
      end
    end)
    |> Enum.sum()
    
    # Combine raw_text from all items
    combined_raw = items
    |> Enum.map(fn item -> item.raw_text end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" | ")
    
    %{base | 
      quantity: total_quantity,
      total_price: :erlang.float_to_binary(total_price, decimals: 2),
      tax_amount: if(total_tax > 0, do: :erlang.float_to_binary(total_tax, decimals: 2), else: nil),
      raw_text: if(combined_raw != "", do: combined_raw, else: base.raw_text)
    }
  end

  defp normalize_store(store) do
    %{
      name: store["name"],
      address: store["address"],
      city: store["city"],
      state: store["state"],
      store_code: store["store_code"],
      phone: store["phone"]
    }
  end

  defp normalize_transaction(txn) do
    %{
      date: txn["date"],
      time: txn["time"],
      subtotal: txn["subtotal"],
      tax: txn["tax"],
      total: txn["total"],
      payment_method: txn["payment_method"]
    }
  end

  defp normalize_item(item) do
    %{
      raw_text: item["raw_text"],
      brand: to_title_case(item["brand"] || ""),
      item: to_title_case(item["item"] || ""),
      quantity: item["quantity"] || 1,
      unit: item["unit"],
      unit_quantity: item["unit_quantity"],
      unit_price: item["unit_price"],
      total_price: item["total_price"],
      taxable: item["taxable"] || false,
      tax_amount: item["tax_amount"],
      store_code: item["store_code"]
    }
  end

  # Common acronyms that should stay uppercase
  @acronyms ~w(TV DVD USB PC AC DC LED LCD HD SD AM PM)

  @doc """
  Converts a string to Title Case, handling ALL CAPS text gracefully.
  Preserves common acronyms in uppercase.
  """
  def to_title_case(nil), do: ""
  def to_title_case(""), do: ""
  def to_title_case(text) when is_binary(text) do
    text
    |> String.split(~r/\s+/)
    |> Enum.map(&format_word/1)
    |> Enum.join(" ")
  end

  defp format_word(word) do
    upper_word = String.upcase(word)
    if upper_word in @acronyms do
      upper_word
    else
      # Check if word is ALL CAPS (needs conversion)
      if word == upper_word and String.length(word) > 1 do
        String.capitalize(String.downcase(word))
      else
        # Already mixed case, leave as-is
        word
      end
    end
  end


  @doc """
  Enriches parsed data with matches from existing database records.
  Marks stores and brands as new or existing.
  Also applies any stored format corrections from user's previous edits.
  """
  def enrich_with_matches(parsed_data, household_id) do
    # Try to match store
    store_match = find_matching_store(parsed_data.store, household_id)
    
    # Try to match brands in items and apply format corrections
    enriched_items = Enum.map(parsed_data.items, fn item ->
      brand_match = find_matching_brand(item.brand, household_id)
      unit_match = find_matching_unit(item.unit, household_id)
      
      # Apply any stored format corrections based on raw_text
      corrected_item = apply_format_correction(item, household_id)
      
      corrected_item
      |> Map.put(:brand_is_new, is_nil(brand_match))
      |> Map.put(:brand_id, brand_match && brand_match.id)
      |> Map.put(:unit_is_new, is_nil(unit_match))
      |> Map.put(:unit_id, unit_match && unit_match.id)
    end)

    result = %{
      store: Map.merge(parsed_data.store, %{
        is_new: is_nil(store_match),
        id: store_match && store_match.id
      }),
      transaction: parsed_data.transaction,
      items: enriched_items
    }

    {:ok, result}
  end

  defp apply_format_correction(item, household_id) do
    case find_format_correction(item.raw_text, household_id) do
      nil -> item
      correction ->
        item
        |> maybe_apply_correction(:brand, correction.corrected_brand)
        |> maybe_apply_correction(:item, correction.corrected_item)
    end
  end

  defp maybe_apply_correction(item, _field, nil), do: item
  defp maybe_apply_correction(item, _field, ""), do: item
  defp maybe_apply_correction(item, field, value), do: Map.put(item, field, value)

  defp find_format_correction(nil, _household_id), do: nil
  defp find_format_correction("", _household_id), do: nil
  defp find_format_correction(raw_text, household_id) do
    import Ecto.Query
    alias MegaPlanner.Receipts.FormatCorrection
    alias MegaPlanner.Repo

    query = from fc in FormatCorrection,
      where: fc.household_id == ^household_id,
      where: fragment("LOWER(?) = LOWER(?)", fc.raw_text, ^raw_text),
      limit: 1

    Repo.one(query)
  end


  defp find_matching_store(%{name: nil}, _household_id), do: nil
  defp find_matching_store(%{name: ""}, _household_id), do: nil
  defp find_matching_store(%{name: store_name} = store_data, household_id) do
    import Ecto.Query
    alias MegaPlanner.Receipts.Store
    alias MegaPlanner.Repo

    # First try exact name match
    query = from s in Store,
      where: s.household_id == ^household_id,
      where: fragment("LOWER(?) = LOWER(?)", s.name, ^store_name),
      limit: 1

    case Repo.one(query) do
      nil ->
        # Try partial match on store code if available
        if store_data[:store_code] do
          code_query = from s in Store,
            where: s.household_id == ^household_id,
            where: s.store_code == ^store_data[:store_code],
            limit: 1
          Repo.one(code_query)
        else
          nil
        end
      store -> store
    end
  end

  defp find_matching_brand(nil, _household_id), do: nil
  defp find_matching_brand("", _household_id), do: nil
  defp find_matching_brand(brand_name, household_id) do
    import Ecto.Query
    alias MegaPlanner.Receipts.Brand
    alias MegaPlanner.Repo

    query = from b in Brand,
      where: b.household_id == ^household_id,
      where: fragment("LOWER(?) = LOWER(?)", b.name, ^brand_name),
      limit: 1

    Repo.one(query)
  end

  defp find_matching_unit(nil, _household_id), do: nil
  defp find_matching_unit("", _household_id), do: nil
  defp find_matching_unit(unit_name, household_id) do
    import Ecto.Query
    alias MegaPlanner.Receipts.Unit
    alias MegaPlanner.Repo

    query = from u in Unit,
      where: u.household_id == ^household_id,
      where: fragment("LOWER(?) = LOWER(?)", u.name, ^unit_name),
      limit: 1

    Repo.one(query)
  end
end
