# Testing Patterns

**Analysis Date:** 2026-03-07

## Test Framework

**Runner:**
- Playwright `^1.58.1` - E2E/integration testing framework
- Config: `client/playwright.config.ts`

**Assertion Library:**
- Playwright built-in assertions: `expect(element).toBeVisible()`, `expect(page).toHaveURL()`

**Run Commands:**
```bash
npx playwright test                        # Run all tests
npx playwright test cross-domain-flows    # Run specific test file
npm run lint                               # ESLint with auto-fix (not directly testing but code quality)
```

## Test File Organization

**Location:**
- E2E tests: `/client/tests/` directory
- No unit tests directory found (all testing is E2E via Playwright)
- Test files co-located with test utilities in same directory

**Naming:**
- Format: `[feature].spec.ts`
- Examples: `budget.spec.ts`, `inventory.spec.ts`, `navigation.spec.ts`
- Global setup/helpers: `global-setup.ts`, `helpers.ts`

**Structure:**
```
client/
├── tests/
│   ├── global-setup.ts          # Authentication setup (runs once)
│   ├── helpers.ts               # Shared test utilities
│   ├── budget.spec.ts           # Budget feature tests
│   ├── inventory.spec.ts        # Inventory feature tests
│   ├── navigation.spec.ts       # Navigation feature tests
│   ├── cross-domain-flows.spec.ts
│   ├── browser-interactions.spec.ts
│   ├── goals.spec.ts
│   ├── habits.spec.ts
│   ├── notes.spec.ts
│   ├── settings.spec.ts
│   └── .auth/                   # Generated during test run
│       └── user.json            # Stored auth state
```

## Test Structure

**Suite Organization:**
```typescript
import { test, expect } from '@playwright/test'
import { navigateWithAuth, expectPageHeaderOrLogin } from './helpers'

test.describe('Budget View', () => {
    test('Budget page loads or redirects to login', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/budget')
        if (loaded) {
            await expect(page.locator('h1, [data-testid="page-title"]')).toBeVisible()
        } else {
            await expect(page).toHaveURL(/login|auth/i)
        }
    })

    test('Displays expense summary when authenticated', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/budget')
        if (!loaded) {
            test.skip()
            return
        }
        // Test logic for authenticated users only
    })
})
```

**Patterns:**
- `test.describe()` for feature grouping
- `test()` for individual test case
- Async test function with `{ page }` fixture from Playwright
- Early exit with `test.skip()` for unauthenticated scenarios
- Helper functions to reduce duplication: `navigateWithAuth`, `isOnLoginPage`

## Mocking

**Framework:** No mocking library found (Playwright doesn't require it for E2E)

**Patterns:**
- Playwright Network Stubbing: API calls not mocked at test level
- Local selectors for elements: CSS selectors, data-testid, text matching
- Multiple selector fallbacks for robustness:
  ```typescript
  const emailInput = page.locator(
    'input[type="email"], input[name="email"], input[placeholder*="email" i]'
  ).first()
  ```
- Locator count checks before interaction: `if (await element.count() > 0) { ... }`

**What to Mock:**
- Authentication state: Saved via `global-setup.ts` which stores auth in `tests/.auth/user.json`
- Not mocking API responses - tests run against real development server

**What NOT to Mock:**
- UI interactions - all real browser interactions
- API calls - all calls go to actual local dev server at `http://localhost:4000`
- Page navigation - uses real routing

## Fixtures and Factories

**Test Data:**
```typescript
// No explicit factory pattern - uses helper functions
export async function navigateWithAuth(page: Page, path: string): Promise<boolean> {
    await page.goto(path)
    await page.waitForLoadState('networkidle')
    await page.waitForTimeout(500)
    return !(await isOnLoginPage(page))
}

export async function isOnLoginPage(page: Page): Promise<boolean> {
    const url = page.url()
    if (url.includes('/login') || url.includes('/auth')) {
        return true
    }
    // Multiple detection methods
    const googleButton = page.locator('button:has-text("Google")').first()
    const loginTestId = page.locator('[data-testid="login"]').first()
    const signInText = page.getByText(/sign in|log in|login|oauth/i).first()
    return (await googleButton.count() > 0) || (await loginTestId.count() > 0) || (await signInText.count() > 0)
}
```

**Location:**
- `client/tests/helpers.ts` - Shared authentication and navigation helpers
- `client/tests/global-setup.ts` - Pre-test authentication setup

## Coverage

**Requirements:** None explicitly enforced in configuration

**View Coverage:**
- No coverage command configured
- Playwright only tests E2E flows, not unit test coverage
- Coverage not a focus for E2E testing approach

## Test Types

**Unit Tests:**
- Not found - no unit test framework (Jest, Vitest, etc.) configured
- Frontend testing is E2E only via Playwright

**Integration Tests:**
- These ARE the primary test type via Playwright
- Tests flow across multiple pages and features
- Authentication required for most tests
- Example: `cross-domain-flows.spec.ts` tests Trip Purchase → Budget Report flow

**E2E Tests:**
- Framework: Playwright `^1.58.1`
- Browser: Chromium (Firefox/Safari commented out)
- Configuration:
  - Base URL: `http://localhost:5173` (dev server)
  - Screenshot: Only on failure
  - Trace: On first retry
  - Parallel execution enabled (workers: undefined allows full parallelization except CI)
  - Retries: 2 on CI, 0 locally
- Authentication: Global setup handles OAuth/login once, state reused across tests

## Common Patterns

**Async Testing:**
```typescript
test('Budget page loads or redirects to login', async ({ page }) => {
    const loaded = await navigateWithAuth(page, '/budget')

    if (loaded) {
        await expect(page.locator('h1, [data-testid="page-title"]')).toBeVisible()
    } else {
        await expect(page).toHaveURL(/login|auth/i)
    }
})
```

**Conditional Test Skipping:**
```typescript
test('Displays expense summary when authenticated', async ({ page }) => {
    const loaded = await navigateWithAuth(page, '/budget')

    if (!loaded) {
        test.skip()  // Skip if not authenticated
        return
    }

    // Only runs if authenticated
    const summary = page.locator('text=/total|spent|expenses/i').first()
    await expect(summary).toBeVisible({ timeout: 5000 }).catch(() => {
        console.log('Expense summary not visible - may need data')
    })
})
```

**Error Handling (Graceful Degradation):**
```typescript
const summary = page.locator('text=/total|spent|expenses/i').first()
await expect(summary).toBeVisible({ timeout: 5000 }).catch(() => {
    console.log('Expense summary not visible - may need data')
})
// Test continues even if element not found
```

**Multiple Selector Fallbacks:**
```typescript
const addButton = page.locator(
    'button:has-text("Add"), [data-testid="add-item"], button:has(svg)'
).first()

if (await addButton.count() > 0) {
    await addButton.click()
}
```

**Navigation Testing:**
```typescript
test('Can navigate to Calendar (may require auth)', async ({ page }) => {
    await page.goto('/')
    await page.waitForLoadState('networkidle')

    const calendarLink = page.locator('a[href*="calendar"], button:has-text("Calendar")').first()
    if (await calendarLink.count() > 0) {
        await calendarLink.click()
        await page.waitForLoadState('networkidle')
    } else {
        await page.goto('/calendar')
        await page.waitForLoadState('networkidle')
    }
})
```

## Test Configuration

**playwright.config.ts:**
```typescript
export default defineConfig({
    testDir: './tests',
    globalSetup: './tests/global-setup.ts',  // Runs once before all tests
    fullyParallel: true,                      // Parallel execution
    forbidOnly: !!process.env.CI,            // Fail if test.only in CI
    retries: process.env.CI ? 2 : 0,         // Retry failed tests on CI
    workers: process.env.CI ? 1 : undefined, // 1 worker on CI, multiple locally
    reporter: 'html',
    use: {
        baseURL: 'http://localhost:5173',
        storageState: authFile,               // Reuse auth from global setup
        trace: 'on-first-retry',              // Trace on failure
        screenshot: 'only-on-failure'
    },
    projects: [
        {
            name: 'setup',
            testMatch: /global-setup\.ts/,
            use: { storageState: undefined }
        },
        {
            name: 'chromium',
            use: { ...devices['Desktop Chrome'] },
            dependencies: ['setup']             // Wait for setup project
        }
    ],
    webServer: {
        command: 'npm run dev',                // Start dev server
        url: 'http://localhost:5173',
        reuseExistingServer: !process.env.CI, // Reuse server locally
        timeout: 120 * 1000,
        env: { VITE_TEST_MODE: 'true' }      // Flag for dev server
    }
})
```

## Authentication Flow

**Global Setup (`tests/global-setup.ts`):**
1. Launches browser independently
2. Navigates to `/login` page
3. Attempts to find and fill email/password inputs
4. Submits form
5. Waits for redirect away from login
6. Saves authentication state to `tests/.auth/user.json`
7. Closes browser

**Test Execution:**
1. Each test reuses the saved auth state via `storageState` option
2. Tests start authenticated (cookies and localStorage preserved)
3. If authentication expires, tests gracefully skip with `test.skip()`

**Environment Variables:**
- `TEST_USER_EMAIL` - Test account email (defaults to `test@example.com`)
- `TEST_USER_PASSWORD` - Test account password (defaults to `testpassword123`)
- `CI` - Set in CI environment to adjust test behavior
- `VITE_TEST_MODE` - Set to `true` when running dev server for tests

## Feature Coverage

**Currently Tested:**
- Navigation and layout (`navigation.spec.ts`)
- Budget and receipts (`budget.spec.ts`)
- Inventory and shopping lists (`inventory.spec.ts`)
- Goals (`goals.spec.ts`)
- Habits (`habits.spec.ts`)
- Notes (`notes.spec.ts`)
- Settings (`settings.spec.ts`)
- Cross-domain data flows (`cross-domain-flows.spec.ts`)
- Browser interactions (`browser-interactions.spec.ts`)

**Test Strategy:**
- All tests are integration/E2E level
- Tests verify page loads and basic functionality
- Many assertions gracefully degrade for missing UI (uses `.catch()`)
- Focus on navigation and authenticated feature access
- Responsive layout testing (desktop and mobile viewports)

---

*Testing analysis: 2026-03-07*
