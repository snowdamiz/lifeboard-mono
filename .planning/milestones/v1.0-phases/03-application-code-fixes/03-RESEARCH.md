# Phase 3: Application Code Fixes - Research

**Researched:** 2026-03-07
**Domain:** Elixir/Ecto SQLite3 adapter compatibility — ilike, async sandbox, foreign_key_constraint, JSONB fragments
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CODE-01 | Replace all `ilike/2` calls with `like/2` across all Ecto query files | ecto_sqlite3 raises `Ecto.QueryError` at runtime on ilike; like/2 with SQLite's default case_sensitive_like: :off is equivalent |
| CODE-02 | Set `async: false` on all ExUnit test cases that use database connections | ecto_sqlite3 adapter docs explicitly state async sandbox is unsupported; two test files have `async: true` with DB sandbox usage; DataCase and AccountsFixtures support modules are missing |
| CODE-03 | Replace `foreign_key_constraint/3` with `validate_change/3` pre-insert checks | SQLite returns `[foreign_key: nil]` — Ecto cannot match nil to a named constraint name, so foreign_key_constraint silently fails and raises unhandled `Ecto.ConstraintError`; 54 FK constraint calls across 31 schema files need audit |
| CODE-04 | Audit and remove Ecto query fragments using JSONB operators | Audit complete — no JSONB fragment operators found in lib/ (->>, ->, @>, ?); CODE-04 is a verification pass only |
</phase_requirements>

## Summary

Phase 3 fixes four categories of PostgreSQL-specific incompatibilities in the application code layer. Phases 1 and 2 addressed dependencies and migration files; this phase targets runtime query code, test infrastructure, and changeset validation.

The most impactful fix is CODE-01: 31 occurrences of `ilike/2` scattered across 5 context modules (`receipts.ex`, `search.ex`, `goals.ex`, `inventory.ex`, `templates.ex`). The `ecto_sqlite3` adapter raises `Ecto.QueryError` — "ilike is not supported by SQLite3" — at the point the query executes, so every code path that calls these functions is currently broken. Replacing `ilike/2` with `like/2` is a safe one-to-one swap because SQLite's LIKE operator is case-insensitive by default (`case_sensitive_like` defaults to `:off`), which is exactly what ilike provided in PostgreSQL.

CODE-02 requires fixing two test files (`receipt_parsing_test.exs`, `habit_inventory_test.exs`) that have `async: true` but use the Ecto SQL Sandbox — incompatible with SQLite's single-writer model. Two other tests use `MegaPlanner.DataCase` which does not yet exist (the module is undefined at compile time). Creating the missing `test/support/` infrastructure (DataCase, ConnCase, AccountsFixtures) is a prerequisite for `mix test` to compile at all. CODE-03 is the largest audit scope (54 FK constraint calls, 31 files) but the fix pattern is uniform. CODE-04 is already resolved — no JSONB operators exist in lib/.

**Primary recommendation:** Execute in order: (1) ilike → like swap in 5 files, (2) create test/support infrastructure and fix async: false, (3) audit and remove foreign_key_constraint calls, (4) document CODE-04 as verified clean.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ecto_sqlite3 | ~> 0.22 | SQLite3 adapter for Ecto | Already installed; adapter under investigation |
| ExUnit | Elixir built-in | Test framework | No alternative |
| Ecto.Adapters.SQL.Sandbox | Built into ecto_sql | Test database isolation | Standard Phoenix test sandbox |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Ecto.Changeset.validate_change/3 | Built-in Ecto | Pre-insert FK existence check | Replaces foreign_key_constraint/3 for SQLite |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| validate_change/3 | assoc_constraint/3 | assoc_constraint requires preloaded association; validate_change is simpler for FK existence |
| validate_change/3 | Keep foreign_key_constraint/3 | foreign_key_constraint/3 is silently broken on SQLite — never converts errors, always raises Ecto.ConstraintError |

## Architecture Patterns

### Recommended Project Structure
```
test/
├── support/
│   ├── data_case.ex          # DB sandbox wrapper (Wave 0 gap — must create)
│   └── fixtures/
│       └── accounts_fixtures.ex  # user_fixture() etc. (Wave 0 gap — must create)
lib/mega_planner/
├── search.ex                 # 10 ilike → like (CODE-01)
├── receipts.ex               # 13 ilike → like (CODE-01)
├── goals.ex                  # 3 ilike → like (CODE-01)
├── inventory.ex              # 4 ilike → like (CODE-01)
└── templates.ex              # 1 ilike → like (CODE-01)
```

### Pattern 1: ilike → like Swap (CODE-01)

**What:** Direct token replacement; semantics are identical under SQLite defaults.

**When to use:** Every occurrence of `ilike(field, ^pattern)` in lib/

**Why it works:** ecto_sqlite3 sets `case_sensitive_like: :off` by default (SQLite PRAGMA `case_sensitive_like = OFF`). SQLite's native LIKE with this pragma active is case-insensitive for ASCII characters, which matches PostgreSQL's ILIKE behavior for the Latin-script strings used in this app (brand names, item names, titles).

**Example:**
```elixir
# Source: ecto_sqlite3 lib/ecto/adapters/sqlite3/connection.ex line 1414
# The adapter explicitly raises on ilike:
defp expr({:ilike, _, [_, _]}, _sources, query) do
  raise Ecto.QueryError,
    query: query,
    message: "ilike is not supported by SQLite3"
end

# BEFORE (PostgreSQL):
where: ilike(g.title, ^"%#{query}%")

# AFTER (SQLite3-compatible):
where: like(g.title, ^"%#{query}%")
```

**Important nuance — exact-match ilike (no wildcards):** Several calls use `ilike(field, ^value)` without `%` wildcards (inventory.ex lines 570-571, 739-740; receipts.ex lines 1028, 1036). With PostgreSQL, `ilike(b.name, ^brand_name)` is case-insensitive equality. With SQLite, `like(b.name, ^brand_name)` with `case_sensitive_like: :off` behaves identically — LIKE without wildcards is a full-string case-insensitive comparison.

### Pattern 2: async: false for DB Tests (CODE-02)

**What:** Remove `async: true` from any ExUnit.Case that uses Ecto.Adapters.SQL.Sandbox.

**Why:** ecto_sqlite3 adapter documentation states explicitly: "The Ecto SQLite3 adapter does not support async tests when used with Ecto.Adapters.SQL.Sandbox. This is due to SQLite only allowing up one write transaction at a time."

**Example:**
```elixir
# Source: ecto_sqlite3 lib/ecto/adapters/sqlite3.ex (official adapter docs)

# BEFORE:
use ExUnit.Case, async: true

setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  ...
end

# AFTER:
use ExUnit.Case, async: false  # SQLite does not support async sandbox

setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  ...
end
```

**Files requiring change:**
- `test/mega_planner/receipt_parsing_test.exs` — line 12: `async: true` → `async: false`
- `test/mega_planner/habit_inventory_test.exs` — line 6: `async: true` → `async: false`
- `test/mega_planner/bug_repro_test.exs` — uses `MegaPlanner.DataCase` (which doesn't exist yet)
- `test/bug_repro_trip_merge_test.exs` — uses `MegaPlanner.DataCase` (which doesn't exist yet)

### Pattern 3: DataCase Support Module (CODE-02 prerequisite)

**What:** Standard Phoenix-generated test helper that wraps ExUnit.Case with DB sandbox setup.

**Why:** Two tests reference `MegaPlanner.DataCase` but the module does not exist. This causes a compile error that prevents `mix test` from running at all.

**Standard DataCase pattern:**
```elixir
# Source: Standard Phoenix generator output, adapted for SQLite (async: false mandatory)
# File: test/support/data_case.ex

defmodule MegaPlanner.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias MegaPlanner.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import MegaPlanner.DataCase
    end
  end

  setup tags do
    MegaPlanner.DataCase.setup_sandbox(tags)
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MegaPlanner.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
```

Note: `DataCase` itself does NOT set `async:`. The test module using `use MegaPlanner.DataCase` must NOT pass `async: true` — leave it absent (defaults to false) or explicitly set `async: false`.

### Pattern 4: AccountsFixtures (CODE-02 prerequisite)

**What:** Test fixture factory for creating test users and households.

**Why:** Two tests reference `MegaPlanner.AccountsFixtures.user_fixture()` but the module doesn't exist. The accounts context has `create_user/1` but not `create_household/1` — the fixture must use `find_or_create_user_from_oauth` or compose Household + User creation directly.

**Example:**
```elixir
# File: test/support/fixtures/accounts_fixtures.ex

defmodule MegaPlanner.AccountsFixtures do
  alias MegaPlanner.{Repo, Accounts}
  alias MegaPlanner.Households.Household

  def household_fixture(attrs \\ %{}) do
    {:ok, household} =
      attrs
      |> Enum.into(%{name: "Test Household #{System.unique_integer()}"})
      |> then(fn a -> %Household{} |> Household.changeset(a) |> Repo.insert() end)
    household
  end

  def user_fixture(attrs \\ %{}) do
    household = household_fixture()
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "user#{System.unique_integer()}@example.com",
        name: "Test User",
        provider: "google",
        provider_id: "#{System.unique_integer()}",
        household_id: household.id
      })
      |> Accounts.create_user()
    user
  end
end
```

### Pattern 5: validate_change/3 Pre-Insert FK Check (CODE-03)

**What:** Query for the referenced record's existence before insert; return changeset error if missing.

**Why:** SQLite's `to_constraints/2` returns `[foreign_key: nil]`. Ecto.Repo.Schema tries to match `nil` against named constraint strings in the changeset — no match occurs — so it raises `Ecto.ConstraintError` (an unhandled exception), not a changeset validation error. The `foreign_key_constraint/3` call in the changeset pipeline provides zero protection.

**Source:** ecto_sqlite3 `lib/ecto/adapters/sqlite3/connection.ex`:
```elixir
def to_constraints(%Exqlite.Error{message: "FOREIGN KEY constraint failed"}, _opts) do
  # unfortunately we have no other date from SQLite
  [foreign_key: nil]
end
```

**Pattern:**
```elixir
# BEFORE: Works in PostgreSQL, silently broken in SQLite
def changeset(task, attrs) do
  task
  |> cast(attrs, [:title, :user_id, :household_id])
  |> foreign_key_constraint(:user_id)       # silently broken on SQLite
  |> foreign_key_constraint(:household_id)  # silently broken on SQLite
end

# AFTER: Works in both
def changeset(task, attrs) do
  task
  |> cast(attrs, [:title, :user_id, :household_id])
  |> validate_change(:user_id, fn :user_id, user_id ->
    if MegaPlanner.Repo.get(MegaPlanner.Accounts.User, user_id) do
      []
    else
      [user_id: "does not exist"]
    end
  end)
  |> validate_change(:household_id, fn :household_id, household_id ->
    if MegaPlanner.Repo.get(MegaPlanner.Households.Household, household_id) do
      []
    else
      [household_id: "does not exist"]
    end
  end)
end
```

**Scope of CODE-03:** 54 `foreign_key_constraint/3` calls across 31 schema files.

### Anti-Patterns to Avoid

- **Keeping foreign_key_constraint/3:** It is silently broken on SQLite. SQLite returns the constraint name as nil; Ecto.Repo.Schema raises Ecto.ConstraintError instead of converting to a changeset error. Remove it.
- **Setting async: true with DB sandbox:** SQLite's single-writer model causes test ordering conflicts. Even if tests pass individually, they will fail under concurrent runs.
- **Using ilike/2 anywhere in Ecto queries targeting SQLite:** The adapter raises at query execution time, not compile time. The bug only appears when the code path is hit at runtime.
- **Assuming JSONB operators work via fragment/2:** They do not. SQLite has no JSONB operator syntax. However, this codebase already uses `fragment("LOWER(?) = LOWER(?)", ...)` patterns that are SQLite-compatible — no JSONB operators found.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Case-insensitive string search | Custom LOWER fragment | `like/2` with SQLite defaults | ecto_sqlite3 sets case_sensitive_like: :off; like/2 is already case-insensitive |
| FK existence validation | Custom DB-level check | `validate_change/3` with Repo.get | Pre-insert Repo.get is the official ecto_sqlite3 recommendation |
| Test DB isolation | Custom transaction wrapper | Ecto.Adapters.SQL.Sandbox in :manual mode | Already configured in test_helper.exs |

**Key insight:** The ecto_sqlite3 adapter documentation prescribes both the like/ilike solution and the FK validation approach. Do not invent alternatives.

## Common Pitfalls

### Pitfall 1: ilike Raises at Runtime, Not Compile Time
**What goes wrong:** The code compiles fine. The error only surfaces when a request reaches the specific code path that executes the ilike query. In a test suite, only tests that exercise that path will fail — silent coverage gap if tests don't cover all search paths.
**Why it happens:** ecto_sqlite3 raises inside the query builder at execution time, not in a macro or compile step.
**How to avoid:** Use `grep -rn "ilike" lib/` to find all occurrences before running; replace all of them in one pass.
**Warning signs:** `** (Ecto.QueryError) ... ilike is not supported by SQLite3` in logs/test output.

### Pitfall 2: async: true Causes Flaky Tests, Not Immediate Failure
**What goes wrong:** Tests with `async: true` may pass in isolation but fail randomly when the full suite runs concurrently, with cryptic `DBConnection.ConnectionError` or "could not checkout connection" errors.
**Why it happens:** SQLite allows only one write transaction at a time. The Sandbox mode wraps each test in a transaction; concurrent async tests create write contention.
**How to avoid:** Always use `async: false` when Ecto SQL Sandbox is in use.
**Warning signs:** Tests pass with `mix test path/to/single_file.exs` but fail with `mix test`.

### Pitfall 3: foreign_key_constraint/3 Appears to Work but Doesn't
**What goes wrong:** The changeset pipeline succeeds with the call included. No error is produced at insert time IF the FK is valid. But if the FK is invalid, instead of a changeset error, an unhandled `Ecto.ConstraintError` exception propagates up to the controller, producing a 500 error instead of a 422.
**Why it happens:** SQLite returns `[foreign_key: nil]` — nil cannot match the constraint name string that Ecto expects. Ecto.Repo.Schema raises instead of converting.
**How to avoid:** Replace with `validate_change/3` doing a pre-insert `Repo.get`. The failure becomes a changeset error before the insert attempt.
**Warning signs:** Application crashes with `** (Ecto.ConstraintError) constraint error when attempting to insert struct` in production logs.

### Pitfall 4: DataCase Missing Blocks All Tests
**What goes wrong:** `mix test` fails at the compilation stage — not during test execution — with "module MegaPlanner.DataCase is not loaded and could not be found".
**Why it happens:** Two test files reference `use MegaPlanner.DataCase` but no `test/support/data_case.ex` file exists.
**How to avoid:** Create `test/support/data_case.ex` before running `mix test`. Note: `mix.exs` already configures `elixirc_paths(:test)` to include `"test/support"`, so the module will be found once created.
**Warning signs:** `== Compilation error in file test/...exs ==` with "cannot compile module" message.

### Pitfall 5: like/2 Without % Wildcards for Exact Matches
**What goes wrong:** Some ilike calls do NOT have `%` wildcards — they are exact case-insensitive equality checks (e.g., `ilike(b.name, ^brand_name)`). A developer might worry that `like(b.name, ^brand_name)` with `case_sensitive_like: :off` does something different.
**Why it doesn't matter:** With `case_sensitive_like = OFF` (SQLite default) and no wildcards, LIKE is a case-insensitive full-string comparison — equivalent to ILIKE with no wildcards in PostgreSQL.
**Warning signs:** None; this is safe. Both PostgreSQL ILIKE and SQLite LIKE (case_sensitive = off) treat `%` and `_` as wildcards when present, and do full-string comparison when absent.

## Code Examples

Verified patterns from official sources:

### ilike → like (Simple Wildcard)
```elixir
# Source: ecto_sqlite3 README and lib/ecto/adapters/sqlite3/connection.ex
# like: " LIKE " at line 835

# Before
where: ilike(t.title, ^search_term)

# After
where: like(t.title, ^search_term)
```

### ilike → like (Exact-Match, No Wildcard)
```elixir
# inventory.ex lines 570-571, 739-740; receipts.ex lines 1028, 1036

# Before
where: ilike(i.brand, ^search_brand) and ilike(i.name, ^search_item)

# After
where: like(i.brand, ^search_brand) and like(i.name, ^search_item)
# SQLite LIKE with case_sensitive_like: :off is case-insensitive with or without %
```

### validate_change/3 for FK Check
```elixir
# Source: Ecto docs, ecto_sqlite3 docs section "Handling foreign key constraints in changesets"

def changeset(struct, attrs) do
  struct
  |> cast(attrs, [:household_id, :user_id])
  |> validate_required([:household_id, :user_id])
  |> validate_change(:household_id, fn :household_id, id ->
    if MegaPlanner.Repo.get(MegaPlanner.Households.Household, id),
      do: [],
      else: [household_id: "does not exist"]
  end)
  # Remove: |> foreign_key_constraint(:household_id)
end
```

### DataCase with SQLite Sandbox (async: false)
```elixir
# Source: Standard Phoenix + ecto_sqlite3 adapter docs

# test/support/data_case.ex
defmodule MegaPlanner.DataCase do
  use ExUnit.CaseTemplate

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MegaPlanner.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end

# test/some_test.exs
defmodule MyTest do
  use MegaPlanner.DataCase  # async: false by default (correct for SQLite)
  ...
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ilike/2` in Ecto queries | `like/2` (SQLite default is case-insensitive) | ecto_sqlite3 adoption | One-to-one swap; no behavior change |
| `foreign_key_constraint/3` | `validate_change/3` pre-insert Repo.get | ecto_sqlite3 0.x limitation | Pre-insert check is safer; FK error becomes changeset error not exception |
| `async: true` DB tests | `async: false` for all sandbox tests | SQLite single-writer model | Required; no alternative |

**Deprecated/outdated:**
- `foreign_key_constraint/3` in SQLite context: documented as non-functional in ecto_sqlite3 since the adapter's first release. The GitHub issue is open and tracked but the SQLite protocol limitation makes it unfixable at the adapter layer.

## Open Questions

1. **CODE-03 scope: fix all 54 FK constraints or only the ones actually hit by the app?**
   - What we know: REQUIREMENTS.md says "audit" — not "replace all". 54 calls across 31 files is a lot.
   - What's unclear: Is the requirement to replace ALL FK constraints, or only the ones likely to fire with invalid data in production?
   - Recommendation: Replace all 54. The cost is uniform and low (each is a 5-line validate_change block). Leaving any in place is a latent 500-error risk. The planner should create one plan task per domain file group.

2. **CODE-04 confirmation: are there JSONB operators in any priv/ or migration files?**
   - What we know: `lib/` is clean — no JSONB operators in fragment strings.
   - What's unclear: The requirement says "context modules" — the requirement is satisfied.
   - Recommendation: Run `grep -rn "fragment" lib/` as a verification step. The planner should include this as a verification task, not an implementation task.

3. **like/2 with non-ASCII characters**
   - What we know: SQLite LIKE with `case_sensitive_like: :off` is only case-insensitive for ASCII (A-Z). Unicode characters (e.g., accented letters) are NOT folded.
   - What's unclear: Does the app store non-ASCII brand names, item names, or user-supplied strings?
   - Recommendation: For this household app the data is English-only (inferred from the domain). Accept the ASCII-only limitation. If Unicode sensitivity becomes an issue, the workaround is `fragment("LOWER(?) LIKE LOWER(?)", field, ^pattern)` — but do not pre-emptively add this complexity.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in Elixir) |
| Config file | none — `mix test` alias in mix.exs handles setup |
| Quick run command | `cd server && mix test` |
| Full suite command | `cd server && mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CODE-01 | No ilike in lib/ | smoke (grep) | `grep -rn "ilike" server/lib/ \| wc -l` returns 0 | ✅ (shell command) |
| CODE-01 | Search functions execute without error | integration | `cd server && mix test` (exercises DB code paths) | ❌ Wave 0 — no search test exists |
| CODE-02 | All DB tests compile and run | integration | `cd server && mix test` | ❌ Wave 0 — DataCase, AccountsFixtures missing |
| CODE-02 | No async: true in DB test files | smoke (grep) | `grep -rn "async: true" server/test/ \| wc -l` returns 0 | ✅ (shell command) |
| CODE-03 | No foreign_key_constraint in lib/ | smoke (grep) | `grep -rn "foreign_key_constraint" server/lib/ \| wc -l` returns 0 | ✅ (shell command) |
| CODE-03 | Insert with invalid FK returns changeset error | unit | part of existing tests that exercise inserts | depends on Wave 0 infrastructure |
| CODE-04 | No JSONB operators in lib/ fragments | smoke (grep) | `grep -rn "fragment" server/lib/ \| grep -v "LOWER\|UPPER\|TRIM"` returns 0 JSONB lines | ✅ (shell command) |

### Sampling Rate
- **Per task commit:** `grep -rn "ilike\|foreign_key_constraint" server/lib/ | wc -l` (quick grep verification)
- **Per wave merge:** `cd server && mix test` (full suite)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `server/test/support/data_case.ex` — required by bug_repro_test.exs and bug_repro_trip_merge_test.exs
- [ ] `server/test/support/fixtures/accounts_fixtures.ex` — required by bug_repro_test.exs and bug_repro_trip_merge_test.exs
- [ ] Verify `mix test` compiles and runs (currently fails at compile due to missing DataCase)

## Sources

### Primary (HIGH confidence)
- `server/deps/ecto_sqlite3/lib/ecto/adapters/sqlite3/connection.ex` line 1414 — ilike raises Ecto.QueryError
- `server/deps/ecto_sqlite3/lib/ecto/adapters/sqlite3/connection.ex` lines 153-157 — to_constraints returns `[foreign_key: nil]`
- `server/deps/ecto_sqlite3/lib/ecto/adapters/sqlite3.ex` — async sandbox docs, case_sensitive_like docs, FK constraint docs
- `server/deps/ecto/lib/ecto/repo/schema.ex` lines 1034-1057 — Ecto raises ConstraintError when constraint name doesn't match

### Secondary (MEDIUM confidence)
- `server/deps/ecto_sqlite3/lib/ecto/adapters/sqlite3.ex` — "case_sensitive_like: :off by default" documentation

### Tertiary (LOW confidence)
- None — all claims verified from source code in deps/

## Metadata

**Confidence breakdown:**
- ilike → like swap (CODE-01): HIGH — ecto_sqlite3 source code confirms raise, and LIKE case-insensitivity is in adapter docs
- async: false (CODE-02): HIGH — ecto_sqlite3 adapter docs explicitly state the limitation
- foreign_key_constraint replacement (CODE-03): HIGH — ecto_sqlite3 to_constraints source returns nil, Ecto.Repo.Schema raises on nil
- JSONB audit (CODE-04): HIGH — grepped all fragment() calls in lib/, none contain JSONB operators
- DataCase/AccountsFixtures gap: HIGH — module compile error confirmed by running mix test

**Research date:** 2026-03-07
**Valid until:** 2026-06-07 (ecto_sqlite3 ~> 0.22 is a stable pinned version)
