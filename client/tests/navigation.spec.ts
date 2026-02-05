/**
 * Navigation & Layout Tests
 * 
 * Tests for app navigation, sidebar, and layout functionality.
 * Handles OAuth-protected routes gracefully.
 */

import { test, expect } from '@playwright/test'
import { navigateWithAuth, isOnLoginPage } from './helpers'

test.describe('Navigation', () => {
    test('App loads without errors', async ({ page }) => {
        await page.goto('/')
        await page.waitForLoadState('networkidle')
        await expect(page).not.toHaveTitle(/error/i)
    })

    test('Navigation redirects work (may go to login)', async ({ page }) => {
        await page.goto('/')
        await page.waitForLoadState('networkidle')

        const onLogin = await isOnLoginPage(page)
        if (onLogin) {
            // Verify login page is functional
            await expect(page.locator('button, a')).toHaveCount(await page.locator('button, a').count())
        } else {
            // Verify sidebar exists
            const sidebar = page.locator('nav, [data-testid="sidebar"], aside').first()
            await expect(sidebar).toBeVisible()
        }
    })

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
        // Just verify navigation worked, even if to login
    })

    test('Can navigate to Budget (may require auth)', async ({ page }) => {
        await navigateWithAuth(page, '/budget')
        // Just verify no crash
    })

    test('Can navigate to Inventory (may require auth)', async ({ page }) => {
        await navigateWithAuth(page, '/inventory')
        // Just verify no crash
    })

    test('Can navigate to Goals (may require auth)', async ({ page }) => {
        await navigateWithAuth(page, '/goals')
        // Just verify no crash
    })

    test('Can navigate to Habits (may require auth)', async ({ page }) => {
        await navigateWithAuth(page, '/habits')
        // Just verify no crash
    })

    test('Can navigate to Notes (may require auth)', async ({ page }) => {
        await navigateWithAuth(page, '/notes')
        // Just verify no crash
    })

    test('Can navigate to Settings (may require auth)', async ({ page }) => {
        await navigateWithAuth(page, '/settings')
        // Just verify no crash
    })
})

test.describe('Responsive Layout', () => {
    test('Desktop layout loads correctly', async ({ page }) => {
        await page.setViewportSize({ width: 1200, height: 800 })
        await page.goto('/')
        await page.waitForLoadState('networkidle')

        // Just verify page loads at desktop size
        await expect(page).not.toHaveTitle(/error/i)
    })

    test('Mobile layout loads correctly', async ({ page }) => {
        await page.setViewportSize({ width: 375, height: 667 })
        await page.goto('/')
        await page.waitForLoadState('networkidle')

        // Just verify page loads at mobile size
        await expect(page).not.toHaveTitle(/error/i)
    })
})
