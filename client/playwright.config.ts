import { defineConfig, devices } from '@playwright/test'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

/**
 * Playwright configuration for Lifeboard browser tests.
 * 
 * Run with: npx playwright test
 * 
 * Requires dev server running: npm run dev
 * 
 * For authenticated tests, set environment variables:
 *   TEST_USER_EMAIL=your-email@example.com
 *   TEST_USER_PASSWORD=your-password
 */

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
const authFile = join(__dirname, 'tests/.auth/user.json')

export default defineConfig({
    testDir: './tests',

    // Global setup runs ONCE before all tests to authenticate
    globalSetup: './tests/global-setup.ts',

    // Run tests in parallel
    fullyParallel: true,

    // Fail the build on CI if you accidentally left test.only in the source code
    forbidOnly: !!process.env.CI,

    // Retry on CI only
    retries: process.env.CI ? 2 : 0,

    // Opt out of parallel tests on CI
    workers: process.env.CI ? 1 : undefined,

    // Reporter
    reporter: 'html',

    use: {
        // Base URL for navigation
        baseURL: 'http://localhost:5173',

        // Reuse authentication state from global setup
        storageState: authFile,

        // Collect trace on failure
        trace: 'on-first-retry',

        // Screenshots on failure
        screenshot: 'only-on-failure',
    },

    projects: [
        // Unauthenticated project (runs first, skips auth)
        {
            name: 'setup',
            testMatch: /global-setup\.ts/,
            use: { storageState: undefined }, // Don't use auth for setup
        },
        // Main authenticated project
        {
            name: 'chromium',
            use: { ...devices['Desktop Chrome'] },
            dependencies: ['setup'], // Wait for setup to complete
        },
        // Uncomment for multi-browser testing
        // {
        //   name: 'firefox',
        //   use: { ...devices['Desktop Firefox'] },
        // },
        // {
        //   name: 'webkit',
        //   use: { ...devices['Desktop Safari'] },
        // },
    ],

    // Run dev server before tests with TEST_MODE enabled
    webServer: {
        command: 'npm run dev',
        url: 'http://localhost:5173',
        reuseExistingServer: !process.env.CI,
        timeout: 120 * 1000,
        env: {
            ...process.env,
            VITE_TEST_MODE: 'true',
        },
    },
})

