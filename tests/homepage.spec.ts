import { test, expect } from '@playwright/test';

test('homepage returns a successful response', async ({ page }) => {
    const response = await page.goto('/');
    expect(response?.status()).toBeLessThan(400);
});

test('homepage is not the GitHub Pages 404 screen', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('body')).not.toContainText("There isn't a GitHub Pages site here");
});

test('homepage title contains site name', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/Danny Makhoul|Dim/i);
});
