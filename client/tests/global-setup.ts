/**
 * Playwright Global Setup - Authentication
 * 
 * This runs ONCE before all tests to:
 * 1. Log in as a test user
 * 2. Save the authentication state (cookies, localStorage)
 * 
 * Tests then reuse this state without logging in again.
 */

import { chromium, FullConfig } from '@playwright/test'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)
const authFile = join(__dirname, '.auth/user.json')

async function globalSetup(config: FullConfig) {
    const browser = await chromium.launch()
    const page = await browser.newPage()

    // Navigate to login page
    const baseURL = config.projects[0].use.baseURL || 'http://localhost:5173'
    await page.goto(`${baseURL}/login`)

    // Wait for page to load
    await page.waitForLoadState('networkidle')

    // Check if we're on login page or already logged in
    const currentUrl = page.url()

    if (currentUrl.includes('/login')) {
        // Fill in login credentials
        // Update these with actual test user credentials
        const testEmail = process.env.TEST_USER_EMAIL || 'test@example.com'
        const testPassword = process.env.TEST_USER_PASSWORD || 'testpassword123'

        // Try to find email/password inputs with various selectors
        const emailInput = page.locator('input[type="email"], input[name="email"], input[placeholder*="email" i]').first()
        const passwordInput = page.locator('input[type="password"], input[name="password"]').first()
        const submitButton = page.locator('button[type="submit"], button:has-text("Log in"), button:has-text("Sign in")').first()

        if (await emailInput.count() > 0 && await passwordInput.count() > 0) {
            await emailInput.fill(testEmail)
            await passwordInput.fill(testPassword)
            await submitButton.click()

            // Wait for redirect after login
            await page.waitForURL((url) => !url.toString().includes('/login'), { timeout: 10000 }).catch(() => {
                console.log('Login may have failed or already logged in')
            })
        } else {
            console.log('Login form not found, assuming OAuth or different auth flow')
        }
    }

    // Save authentication state
    await page.context().storageState({ path: authFile })

    await browser.close()

    console.log('✅ Global setup complete - auth state saved')
}

export default globalSetup
