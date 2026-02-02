---
description: How to parse and learn from receipt scans, including store-specific patterns
---

# Receipt Parsing Skill

This skill documents how the LifeBoard receipt parsing system works, how it learns from user corrections, and how to handle different receipt types.

## Overview

The receipt parsing system follows a **Proposal-Review-Persist** pattern:

1. **Proposal**: AI extracts structured data from receipt image (no DB writes)
2. **Review**: User reviews/edits the proposed items in the UI
3. **Persist**: User confirms → entities are created in the database

## Key Files

- `server/lib/mega_planner/receipts/receipt_parser.ex` - AI-powered extraction
- `server/lib/mega_planner_web/controllers/receipt_upload_controller.ex` - API endpoints
- `server/lib/mega_planner/receipts/format_correction.ex` - Learning storage
- `client/src/components/calendar/ReceiptScanModal.vue` - Review UI

## Learning System

### What We Learn From User Corrections

When a user edits a receipt item before confirming, we save a `FormatCorrection` record that maps:

| Field | Purpose |
|-------|---------|
| `raw_text` | The original OCR text from the receipt line |
| `corrected_brand` | User's preferred brand name |
| `corrected_item` | User's preferred item name |
| `corrected_unit` | User's preferred unit (e.g., "oz" → "Ounce") |
| `corrected_quantity` | User's quantity interpretation |
| `preference_notes` | JSON for future extensibility |

### How Corrections Are Applied

In `receipt_parser.ex`, the `enrich_with_matches/2` function:
1. Looks up existing `FormatCorrection` records by raw_text
2. Applies corrected values to the AI proposal before returning to UI
3. Marks brands/units as `is_new` or existing

### When Entities Are Created

**IMPORTANT**: Brands, Units, and Items are ONLY created AFTER:
1. The purchase is successfully inserted into the database
2. The user has confirmed the final item data

This ensures no "garbage" entities from rejected/deleted items.

## Tax Handling

The AI extracts tax information for each item and calculates tax amounts based on receipt indicators.

### Tax Indicator Codes

| Code | Meaning | Taxable | Store Examples |
|------|---------|---------|----------------|
| **N** | Non-taxable (food/grocery) | ❌ false | Walmart, Target |
| **X** or **T** | Taxable at state rate | ✅ true | Walmart |
| **A** | Taxable | ✅ true | Costco |
| **F** | Food Stamp Eligible | ❌ false | Walmart |
| (blank) | Check item type | Varies | All stores |

### Tax Calculation Rules

For **each taxable item**, the AI calculates:

```
tax_amount = total_price × tax_rate
```

**Example (Michigan 6% tax):**

| Item | Price | Indicator | Taxable | Tax Rate | Tax Amount |
|------|-------|-----------|---------|----------|------------|
| Strawberries | $6.34 | N | false | null | null |
| Gas Can | $34.88 | X | true | 0.06 | $2.09 |
| Light Bulbs | $12.50 | X | true | 0.06 | $0.75 |

### Fields Extracted Per Item

| Field | Type | Description |
|-------|------|-------------|
| `tax_indicator` | string | Raw code from receipt (N, X, T, A, F) |
| `taxable` | boolean | Whether item is taxed |
| `tax_rate` | decimal | Rate as decimal (e.g., 0.06 for 6%) |
| `tax_amount` | decimal | Calculated: `total_price × tax_rate` |

### Tax Indicator Learning

User corrections to tax indicators are stored in the `tax_indicator_meanings` table:

```elixir
# Schema: TaxIndicatorMeaning
- household_id: uuid
- store_name: string (e.g., "Walmart")
- indicator: string (e.g., "N")
- is_taxable: boolean
- description: string
- default_tax_rate: decimal
```

When parsing future receipts, learned meanings are applied via:
```elixir
Receipts.apply_tax_indicator_meaning(item, household_id, store_name)
```

## Store-Specific Patterns

### Costco Receipts

Costco receipts have unique characteristics:

**Format quirks:**
- Item names are heavily abbreviated (e.g., "KS ORG XVOO 2L" = Kirkland Signature Organic Extra Virgin Olive Oil 2L)
- Item codes are 6-7 digits, usually start with item number
- "KS" or "KIRKLAND" prefix indicates store brand
- Quantity is often embedded in item name ("3PK", "2CT", etc.)
- Tax indicators: "A" (taxed), blank (not taxed)

**Common abbreviations to learn:**
```
KS = Kirkland Signature
ORG = Organic
XVOO = Extra Virgin Olive Oil
GRN = Green
CKN = Chicken
VEG = Vegetable
FRZ = Frozen
RF = Refrigerated
```

**Prompt enhancements for Costco:**
When detecting a Costco receipt (by store name containing "COSTCO"), the AI prompt could include:
- "KS" and "KIRKLAND" indicate Kirkland Signature brand
- Parse quantity from embedded text like "3PK" or "2CT"
- Item codes are significant for future matching

### Walmart Receipts

**Format quirks:**
- "GV" prefix = Great Value (store brand)
- Tax codes appear at end of price line (e.g., "$6.34 N", "$34.88 X")
- Tax rate shown as "TAX1 6.0000%" or "TAX 6.00%"
- Item codes may have letters (e.g., "K123456")

**Tax codes:**
| Code | Meaning |
|------|---------|
| N | Non-taxable (food) |
| X | Taxable at state rate |
| T | Taxable |
| F | Food stamp eligible (non-taxable) |

### Target Receipts

**Format quirks:**
- "UP&UP" is store brand
- DPCI codes follow format XXX-XX-XXXX
- Circle discounts shown separately

## Enhancing the AI Prompt

The extraction prompt in `receipt_parser.ex` (`build_extraction_prompt/0`) should be enhanced with store-specific rules when we detect the store type:

```elixir
defp build_extraction_prompt(store_type \\ :generic) do
  base_prompt = "..."
  
  store_hints = case store_type do
    :costco -> """
    COSTCO-SPECIFIC RULES:
    - "KS" or "KIRKLAND" prefix = Kirkland Signature brand
    - Parse quantities from text like "3PK", "2CT", "6PK"
    - Item codes are 6-7 digit numbers
    """
    :walmart -> """
    WALMART-SPECIFIC RULES:
    - "GV" prefix = Great Value brand
    - Tax code "T" = taxed item
    """
    _ -> ""
  end
  
  base_prompt <> store_hints
end
```

## Adding New Store Patterns

1. Save example receipts to analyze patterns
2. Document abbreviations and format quirks
3. Add store detection logic to `receipt_parser.ex`
4. Create store-specific prompt hints
5. Test with real receipts and refine

## Debugging

Check the `format_corrections` table to see what users are teaching the system:

```elixir
# In IEx
import Ecto.Query
alias MegaPlanner.{Repo, Receipts.FormatCorrection}

# View recent corrections
from(fc in FormatCorrection, order_by: [desc: fc.updated_at], limit: 10)
|> Repo.all()

# See corrections for a specific raw text pattern
from(fc in FormatCorrection, where: ilike(fc.raw_text, "%COSTCO%"))
|> Repo.all()
```

## Future Improvements

1. **Store type detection**: Automatically detect store type from receipt header
2. **Fuzzy matching**: Apply corrections to similar (not just exact) raw_text
3. **Batch learning**: Learn from all household members' corrections
4. **Confidence scoring**: Show confidence level for each extracted field
5. **Store-specific prompts**: Dynamically inject store hints into AI prompt
