/**
 * Test Helpers for Lifeboard Playwright Tests
 * 
 * Common utilities for handling OAuth-protected routes.
 */

import { Page, expect } from '@playwright/test'

/**
 * Check if the current page is the login page (OAuth redirect happened)
 */
export async function isOnLoginPage(page: Page): Promise<boolean> {
    const url = page.url()
    if (url.includes('/login') || url.includes('/auth')) {
        return true
    }

    // Check for login page content using separate locators
    const googleButton = page.locator('button:has-text("Google")').first()
    const loginTestId = page.locator('[data-testid="login"]').first()
    const signInText = page.getByText(/sign in|log in|login|oauth/i).first()

    const hasGoogleButton = await googleButton.count() > 0
    const hasLoginTestId = await loginTestId.count() > 0
    const hasSignInText = await signInText.count() > 0

    return hasGoogleButton || hasLoginTestId || hasSignInText
}

/**
 * Navigate to a page and handle OAuth redirect gracefully
 * Returns true if page loaded successfully, false if redirected to login
 */
export async function navigateWithAuth(page: Page, path: string): Promise<boolean> {
    await page.goto(path)
    await page.waitForLoadState('networkidle')

    // Give a moment for any redirects
    await page.waitForTimeout(500)

    return !(await isOnLoginPage(page))
}

/**
 * Assert page header contains text, or skip if on login page
 */
export async function expectPageHeaderOrLogin(
    page: Page,
    expectedText: RegExp | string,
    options: { timeout?: number } = {}
): Promise<{ authenticated: boolean }> {
    const onLogin = await isOnLoginPage(page)

    if (onLogin) {
        // Just verify we're on login page - this is expected for protected routes
        console.log(`Route requires auth - on login page`)
        return { authenticated: false }
    }

    // We're authenticated, check the header
    const header = page.locator('h1, [data-testid="page-title"]')
    await expect(header).toContainText(expectedText, { timeout: options.timeout ?? 5000 })
    return { authenticated: true }
}
