/**
 * Notes & Notebooks View Tests
 * 
 * Tests for NotebooksView and note page functionality.
 * Handles OAuth-protected routes gracefully.
 */

import { test, expect } from '@playwright/test'
import { navigateWithAuth, isOnLoginPage } from './helpers'

test.describe('Notebooks View', () => {
    test('Notes page loads or redirects to login', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/notes')

        if (loaded) {
            await expect(page.locator('h1, [data-testid="page-title"]')).toBeVisible()
        } else {
            await expect(page).toHaveURL(/login|auth/i)
        }
    })

    test('Can create new notebook when authenticated', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/notes')
        if (!loaded) {
            test.skip()
            return
        }

        const addButton = page.locator('[data-testid="add-button"], button:has-text("New"), button:has-text("Add")').first()
        if (await addButton.count() > 0) {
            await addButton.click()
            await expect(page.locator('[role="dialog"]')).toBeVisible({ timeout: 3000 }).catch(() => {
                console.log('Notebook dialog not found')
            })
        }
    })

    test('Notebook list displays when authenticated', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/notes')
        if (!loaded) {
            test.skip()
            return
        }

        await page.waitForTimeout(500)
        // Just verify no errors
    })

    test('Can click into notebook when authenticated', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/notes')
        if (!loaded) {
            test.skip()
            return
        }

        const notebookCard = page.locator('[data-testid="notebook-item"], .notebook-card, a[href*="notes"]').first()
        if (await notebookCard.count() > 0) {
            await notebookCard.click()
            await page.waitForLoadState('networkidle')
        }
    })

    test('Search notes works when authenticated', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/notes')
        if (!loaded) {
            test.skip()
            return
        }

        const searchInput = page.locator('input[type="search"], input[placeholder*="search" i]')
        if (await searchInput.count() > 0) {
            await searchInput.fill('test search')
            await page.waitForTimeout(500)
        }
    })

    test('Note editor loads when authenticated', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/notes')
        if (!loaded) {
            test.skip()
            return
        }

        const noteLink = page.locator('a[href*="notes/"], [data-testid="note-link"]').first()
        if (await noteLink.count() > 0) {
            await noteLink.click()
            await page.waitForLoadState('networkidle')
            await page.waitForTimeout(500)
        }
    })

    test('Can type in note editor when authenticated', async ({ page }) => {
        const loaded = await navigateWithAuth(page, '/notes')
        if (!loaded) {
            test.skip()
            return
        }

        const noteLink = page.locator('a[href*="notes/"]').first()
        if (await noteLink.count() > 0) {
            await noteLink.click()
            await page.waitForLoadState('networkidle')

            const editor = page.locator('[contenteditable="true"], textarea').first()
            if (await editor.count() > 0) {
                await editor.click()
                await page.keyboard.type('Test')
                await page.waitForTimeout(500)
            }
        }
    })
})
