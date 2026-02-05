---
description: How to run functional regression tests and interpret failures
---

# Functional Testing Workflow

This workflow documents how to run the automated functional tests before and after refactoring.

## Prerequisites

- Development environment set up (see `/setup_dev_env`)
- Database running with test configuration

## Running Tests

### Full Test Suite

```bash
// turbo
cd server
mix test test/functional_regression_test.exs
```

### Verbose Output (Debug Failures)

```bash
cd server
mix test test/functional_regression_test.exs --trace
```

### Specific Test by Line

```bash
cd server
mix test test/functional_regression_test.exs:50
```

## Interpreting Results

### All Tests Pass ✅

```
Finished in 2.3 seconds
25 tests, 0 failures
```

**Meaning**: Backend data layer is working correctly.

### Some Tests Fail ❌

```
1) test Tasks round-trip: create → load → edit → delete (...)
   Assertion with == failed
   left:  nil
   right: "Updated meeting"
```

**What to check**:

| Failure Phase | Common Cause | Fix |
|---------------|--------------|-----|
| CREATE | Schema mismatch | Check changeset validations |
| LOAD | Insert didn't commit | Check Ecto sandbox mode |
| EDIT | Update rejected | Check update function |
| DELETE | FK constraint | Add cascade or delete deps |

## Expected Failures

> **IMPORTANT**: Not all tests will pass immediately. The test suite is designed to be **aspirational** - it tests what SHOULD work, not what currently works.

### Known Gaps

Some tests may fail because:

1. **API signatures differ**: The test assumes a function signature that doesn't match actual code
2. **Missing features**: Delete propagation for tags may not be implemented
3. **Schema differences**: Field names may not match exactly

### How to Handle Failures

1. **Read the error message** - It tells you exactly what failed
2. **Check the function** - Does `Budget.delete_entry/1` exist? What args does it take?
3. **Fix the test OR fix the code** - Decide which is correct
4. **Document the fix** - Update this workflow if you discover patterns

## Adding New Tests

When adding a new feature, add a corresponding round-trip test:

```elixir
describe "NewFeature round-trip: create → load → edit → delete" do
  test "feature survives full CRUD cycle", ctx do
    # 1. CREATE
    {:ok, item} = Module.create_thing(ctx.household.id, %{"field" => "value"})
    
    # 2. LOAD
    loaded = Module.get_thing(item.id)
    assert loaded.field == "value"
    
    # 3. EDIT
    {:ok, _} = Module.update_thing(item, %{"field" => "new_value"})
    reloaded = Module.get_thing(item.id)
    assert reloaded.field == "new_value"
    
    # 4. DELETE
    {:ok, _} = Module.delete_thing(item)
    assert Module.get_thing(item.id) == nil
  end
end
```

## Troubleshooting

### "function does not exist"

The test calls a function that doesn't exist. Either:
- Add the function to the context module
- Update the test to call the correct function

### "no match of right hand side"

The function returned an error tuple. Check:
- Required fields are provided
- Validation rules pass
- Foreign keys exist

### "assertion failed"

The data doesn't match expectations. Check:
- Field names match schema
- Types are correct (string vs atom, Decimal vs float)
- Update actually committed

## Browser Interaction Tests (Playwright)

### Setup

```bash
cd client
npm install -D @playwright/test
npx playwright install
```

### Running Browser Tests

```bash
// turbo
cd client
npx playwright test
```

### What They Test

| Category | Tests |
|----------|-------|
| **Hover** | Button hover states, tooltips |
| **Click** | Modal open/close, form submit |
| **Drag** | Task drag between days, inventory transfer |
| **Keyboard** | Tab navigation, Enter/Space activation, Escape close |
| **Round-trip** | Add → Fill → Submit → Verify appears |

### Test Fixtures

The tests require `data-testid` attributes on elements:
- `data-testid="add-button"`
- `data-testid="edit-button"`
- `data-testid="delete-button"`
- `data-testid="task-card"`
- etc.

## See Also

- [Testing Guide](file:///C:/Users/yurlo/.gemini/antigravity/brain/088205f8-261f-4af5-90d0-7cf003ab20d6/testing_guide.md) - Diagrams explaining test design
- [Receipt Parsing](/receipt-parsing) - Related workflow for receipt testing
