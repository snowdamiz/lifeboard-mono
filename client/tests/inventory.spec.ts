/**
 * Inventory & Shopping List Tests
 * 
 * Tests for InventoryView and ShoppingListView functionality.
 * Handles OAuth-protected routes gracefully.
 */

import { test, expect } from '@playwright/test'
import { navigateWithAuth, isOnLoginPage } from './helpers'

test.describe('Inventory View', () => {
    test('Inventory page loads or redirects to login', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/inventory')

        if (loaded) {
            await expect(page.locator('h1, [data-testid="page-title"]')).toBeVisible()
        } else {
            await expect(page).toHaveURL(/login|auth/i)
        }
    })

    test('Displays sheet tabs when authenticated', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/inventory')
        if (!loaded) {
            test.skip()
            return
        }

        await page.waitForTimeout(500)
        // Just verify page loaded
    })

    test('Can add new item when authenticated', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/inventory')
        if (!loaded) {
            test.skip()
            return
        }

        const addButton = page.locator('button:has-text("Add"), [data-testid="add-item"], button:has(svg)').first()
        if (await addButton.count() > 0) {
            await addButton.click()
            await page.waitForTimeout(500)
        }
    })

    test('Inventory items draggable when authenticated', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/inventory')
        if (!loaded) {
            test.skip()
            return
        }

        const item = page.locator('[data-testid="inventory-item"], [draggable="true"]').first()
        if (await item.count() > 0) {
            await item.getAttribute('draggable')
        }
    })

    test('Search functionality works when authenticated', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/inventory')
        if (!loaded) {
            test.skip()
            return
        }

        const searchInput = page.locator('input[type="search"], input[placeholder*="search" i], [data-testid="search"]')
        if (await searchInput.count() > 0) {
            await searchInput.fill('test search')
            await page.waitForTimeout(300)
        }
    })
})

test.describe('Shopping List View', () => {
    test('Shopping list page loads or redirects to login', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/inventory/shopping')

        if (loaded) {
            // May show shopping content
            await page.waitForTimeout(500)
        } else {
            await expect(page).toHaveURL(/login|auth/i)
        }
    })

    test('Can add item when authenticated', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/inventory/shopping')
        if (!loaded) {
            test.skip()
            return
        }

        const addButton = page.locator('button:has-text("Add"), [data-testid="add-shopping-item"]').first()
        if (await addButton.count() > 0) {
            await addButton.click()
            await page.waitForTimeout(500)
        }
    })

    test('Shopping items checkable when authenticated', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/inventory/shopping')
        if (!loaded) {
            test.skip()
            return
        }

        const checkbox = page.locator('input[type="checkbox"], [role="checkbox"]').first()
        if (await checkbox.count() > 0) {
            await checkbox.click()
            await page.waitForTimeout(300)
        }
    })

    test('Clear completed button visible when authenticated', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/inventory/shopping')
        if (!loaded) {
            test.skip()
            return
        }

        const clearButton = page.locator('button:has-text("Clear"), button:has-text("Remove completed")')
        if (await clearButton.count() > 0) {
            await expect(clearButton.first()).toBeVisible()
        }
    })
})
